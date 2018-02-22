#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename;
use Getopt::Long;
use FindBin qw($Bin);
use lib "$Bin/ext/lib/perl5";
use Parallel::ForkManager;

my $version=0.1.0;
my $script_desc="To Calculate various statistics from the sorted mapping file in BAM format. 
    Output: bamFileName.stats.txt";

my $numCPUs=4;
my $expect_best_qual=37;
my $expect_bwa_MapQ=60;
my $expectedCoverage=1;
my $expectedIdentity=1;
my $quality_calculation_cutoff=0.95**4;
my $depth_cutoff=1000; 
my $mode="PE";
my ($coverageWeight, $identityWeight, $baseqWeight, $mapqWeight) = (0.25, 0.25, 0.25, 0.25);
my $read_length_cutoff="100";
my $outDir;
my $target_file;
GetOptions(
            "o=s"              => \$outDir,
            "c=i"              => \$numCPUs,
            "ref=s"            => \$target_file,
            "q_cutoff=f"       => \$quality_calculation_cutoff,
            "depth_cutoff=i"   => \$depth_cutoff,
            "mode=s"           => \$mode,
            "expectedCoverage=f" => \$expectedCoverage,
            "expectedIdentity=f" => \$expectedIdentity,
            "expectedBaseQ=i"  => \$expect_best_qual,
            "expectedMapQ=i"   => \$expect_bwa_MapQ,
            "coverageWeight=f" => \$coverageWeight,
            "identityWeight=f" => \$identityWeight,
            "baseqWeight=f"    => \$baseqWeight,
            "mapqWeight=f"     => \$mapqWeight,
            "len_cutoff=i" => \$read_length_cutoff,
            "version"          => sub{print "Version $version\n";exit;},
            "help|?"           => sub{Usage($script_desc)} );

$ENV{PATH} = "$Bin/ext/miniconda/bin:$ENV{PATH}";

my $bamFile=$ARGV[0];
if (!@ARGV){Usage($script_desc);}
if ( ! -e $bamFile){&Usage("Bam file doesn't exist");}
if ( ! -e $target_file){&Usage("Reference file doesn't exist");}
if ( $expectedCoverage<=0 or $expectedCoverage>1) {&Usage("Expected coverage must be a number > 0 and <=1 !");}
if ( $expectedIdentity<=0 or $expectedIdentity>1) {&Usage("Expected identity must be a number > 0 and <=1 !");}
if ( $coverageWeight<0 or $coverageWeight>1) {&Usage("Coverage weight must be a number between 0 and 1!");}
if ( $identityWeight<0 or $identityWeight>1) {&Usage("Identity weight must be a number between 0 and 1!");}
if ( $baseqWeight<0 or $baseqWeight>1) {&Usage("BaseQ weight must be a number between 0 and 1!");}
if ( $mapqWeight<0 or $mapqWeight>1) {&Usage("MapQ weight must be a number between 0 and 1!");}


my ($file_name, $file_path, $file_suffix)=fileparse("$bamFile", qr/\.[^.]*/);
if (! $outDir) {$outDir=$file_path;}
system ("mkdir -p $outDir");

if (! -e "$bamFile.bai") 
{
	system ("samtools index $bamFile");
}

&process($bamFile,$target_file,$numCPUs);

exit 0;

#### SUB  ####
sub process
{
	my $bamFile=shift;
	my $target_file=shift;
	my $numCPUs=shift;
	
   # my ($targets_r,$total_reads_count)= &mapped_reads_per_ref($bamFile);
	my $targets_r = &get_fasta_seq($target_file);
	my @targets = keys %$targets_r;
#use Data::Dumper;
	my ($file_name, $file_path, $file_suffix)=fileparse("$bamFile", qr/\.[^.]*/);
	my $stats_file="$outDir/$file_name.mapping_stats.txt";
	my $run_stats_file="$outDir/$file_name.run_stats.txt";
	my $report_file="$outDir/$file_name.report.txt";
	unlink $stats_file if (-e $stats_file);
	unlink $run_stats_file if (-e $run_stats_file);
	unlink $report_file if (-e $report_file);
	my @headers=('SampleID','Target','Length','Quality_Calculation',
	'Depth_Mean','Depth_RMS','Depth_StdDev','Depth_SNR','Coverage','Match_Bases','Mismatch_Bases',
	'Total_Bases','Identity','BaseQ_mean','BaseQ_RMS','BaseQ_StdDev','BaseQ_SNR','Match_BaseQ_mean',
	'Match_BaseQ_RMS','Match_BaseQ_StdDev','Match_BaseQ_SNR','Mismatch_BaseQ_mean','Mismatch_BaseQ_RMS',
	'Mismatch_BaseQ_StdDev','Mismatch_BaseQ_SNR','MapQ_mean','MapQ_RMS','MapQ_StdDev','MapQ_SNR',
	'Mapped_Reads','Fraction_Reads','Determination');
	my @report_header=('SampleID','Target','Determination','Depth_Mean','Quality_Calculation');
	open (my $stats_fh, ">$stats_file") or die "Cannot write to $stats_file\n";
	open (my $report_fh, ">$report_file") or die "Cannot write to $report_file\n";
	print $stats_fh join("\t",@headers),"\n";
	print $report_fh join("\t",@report_header),"\n";
	my $result=&processBam($bamFile,$targets_r,$target_file,$file_name);
	
	foreach my $target (sort @targets ){
		print $stats_fh $file_name."\t".$target."\t".$targets_r->{$target}->{len}."\t";
		
		foreach my $i (3..$#headers){
				my $statName= $headers[$i];
				print $stats_fh $result->{$target}->{$statName},"\t"; 
		}
		
		if ( $result->{$target}->{Determination} ne "Negative"){
			print $report_fh $file_name."\t".$target."\t";
			foreach my $i (2..$#report_header){
					my $statName= $report_header[$i];
					print $report_fh $result->{$target}->{$statName},"\t"; 
			}
			print $report_fh "\n";
		}
		print $stats_fh "\n";
	}
	close $stats_fh;
	close $report_fh;
	
	open (my $run_stats_fh, ">$run_stats_file") or die "Cannot write to $run_stats_file\n";
	my @run_stats_headers=('SampleID','Prefilter_Reads','Unmapped_Reads','Percent_Unmapped_Reads','Mapped_Singlets',
	'Percent_Mapped_Singlets','Postfilter_Reads','Discarded_Reads','Discarded_Percent');
	print $run_stats_fh join("\t",@run_stats_headers),"\n";
	print $run_stats_fh  $file_name."\t";
	foreach my $i (1..$#run_stats_headers){
		my $statName= $run_stats_headers[$i];
		print $run_stats_fh $result->{$file_name}->{$statName},"\t";
	}
	print $run_stats_fh "\n";
	close $run_stats_fh;
	return 0;
}

sub processBam
{
	my $bamFile=shift;
	my $target_seq_r=shift;
	my $target_file=shift;
	my $sample_name=shift;
	my @targets = sort keys %$target_seq_r;
	
	
	my %results;
	my %mapQ;
	my %total_qual;
	my %match_qual;
	my %match_base;
	my %mismatch_base;
	my %mismatch_qual;
	my %coverage_r;

	# initalized coverage array
	foreach my $target (@targets){
		my $target_len = $target_seq_r->{$target}->{len};
		@{$coverage_r{$target}}= (0) x $target_len;
	}
	
	open (my $fh,"samtools calmd -e $bamFile $target_file 2>/dev/null | ");
	#NC_001477.1-9306	83	NC_001477.1	1712	60	150M	=	1559	-303	========A===============================================================T====================================================A=================T===A==	GGGGG@GF+CFGGFGGDGGGGGGGGGGGGFGDEGGG<GGGG?FG>GGFGG,GFGGGGGGG1GGGF8GG<GEG*GCGG2DGG,GGGDGCGGGGGGGGGGGGGGGCC>GGGCDCGFGFF#7CGGG#E#*GGGGGFFFGGFACGGC#GG0#CG	NM:i:5	MD:Z:8T63A52G17G3G2	AS:i:128	XS:i:0
	my $prefilter_reads=0;
	my $unmapped_reads=0;
	my $mapped_singlets=0;
	my $postfilter_reads=0;
	
	while(<$fh>)
	{
		next if (/^@/);
		chomp;
		my @array = split /\t/,$_;
		my $read_id=$array[0];
		my $flag=$array[1];
		next if ($flag & 256 || $flag & 512);
		#$unpaired_reads++ if ($flag & 4 && $flag & 8);
		$prefilter_reads++;
		my $ref_id=$array[2];
		my $start_pos=$array[3];
		my $mapQ=$array[4];
 		my $CIGAR=$array[5];
		my $mate_ref_id=$array[6];
		my $insert_size=$array[8];
		my $target_len = $target_seq_r->{$ref_id}->{len};
		next if ( length $array[9] < $read_length_cutoff);
		if (($flag & 2 && $mode eq "PE") || ( !$flag & 4 && $mode eq "SE")){
			$mapQ{$ref_id}->{$mapQ}++;
			$postfilter_reads++;
			$results{$ref_id}->{Mapped_Reads}++;
			# treat deletion with mismatch with zero quality. 
			# no need to deal with insertion because it is already part of samtools calmd output as mismatch
			my (@deletions) = $CIGAR =~ /(\d+)D/g;
			my ($softClip_5) = $CIGAR =~ /^(\d+)S/;
			my ($softClip_3) = $CIGAR =~ /(\d+)S$/;
			my @seq=split //,$array[9];
			my @qual=split /\s+/,&quality_encoding_coversion($array[10]);
			my $seq_start = ($softClip_5)? $softClip_5-1 : 0 ;
			my $seq_end = ($softClip_3)? $#qual - $softClip_3 : $#qual ;

			for my $qi ($seq_start..$seq_end){
				my $cover_pos = $start_pos - 1 + $qi - $seq_start;
				$coverage_r{$ref_id}->[$cover_pos]++ if ($target_len > $cover_pos);
				my $q_value = $qual[$qi];
				$total_qual{$ref_id}->{$q_value}++;
				if ($seq[$qi] eq "="){
					$match_base{$ref_id}->{match_bases}++;
					$match_qual{$ref_id}->{$q_value}++;
				}else{
					$mismatch_base{$ref_id}->{mismatch_bases}++;
					$mismatch_qual{$ref_id}->{$q_value}++;
				}
			}
			if (@deletions){
				foreach my $deletion (@deletions){
					$mismatch_base{$ref_id}->{mismatch_bases} += $deletion;
					$mismatch_qual{$ref_id}->{0} += $deletion;
				}
			}
		}elsif($flag & 4){
			$unmapped_reads++;
		}elsif($flag & 8){
			$mapped_singlets++;
		}
	}
	close $fh;
	my $percent_unmapped_reads = ($prefilter_reads)? $unmapped_reads/$prefilter_reads : 0;
	my $percent_mapped_singlets = ($prefilter_reads)? $mapped_singlets/$prefilter_reads : 0 ;
	$results{$sample_name}->{Prefilter_Reads}=$prefilter_reads;
	$results{$sample_name}->{Unmapped_Reads}=$unmapped_reads;
	$results{$sample_name}->{Percent_Unmapped_Reads}=$percent_unmapped_reads;
	$results{$sample_name}->{Mapped_Singlets}=$mapped_singlets;
	$results{$sample_name}->{Percent_Mapped_Singlets}=$percent_mapped_singlets;
	$results{$sample_name}->{Postfilter_Reads}=$postfilter_reads;
	$results{$sample_name}->{Discarded_Reads}=$prefilter_reads - $postfilter_reads;
	$results{$sample_name}->{Discarded_Percent}=($prefilter_reads)?($prefilter_reads - $postfilter_reads)/$prefilter_reads : 0;
	
	
	foreach my $target(@targets){
		my $quality_calculation=0;
		my ($Depth_StdDev,$Depth_Mean,$Coverage,$Depth_RMS,$Depth_SNR) = (0,0,0,0,0);
		if ($coverage_r{$target}){
			($Depth_StdDev,$Depth_Mean,$Coverage,$Depth_RMS,$Depth_SNR)=&get_statistics($target_seq_r->{$target}->{len},@{$coverage_r{$target}});
		}
	
		$results{$target}->{Depth_StdDev}=$Depth_StdDev;
		$results{$target}->{Depth_Mean}=$Depth_Mean;
		$results{$target}->{Coverage}=$Coverage;
		$results{$target}->{Depth_RMS}=$Depth_RMS;
		$results{$target}->{Depth_SNR}=$Depth_SNR;
		
		my ($BaseQ_StdDev,$BaseQ_mean,$BaseQ_RMS,$BaseQ_SNR)=&get_statistics_from_hash($total_qual{$target});
		my ($Match_BaseQ_StdDev,$Match_BaseQ_mean,$Match_BaseQ_RMS,$Match_BaseQ_SNR)=&get_statistics_from_hash($match_qual{$target});
		my ($Mismatch_BaseQ_StdDev,$Mismatch_BaseQ_mean,$Mismatch_BaseQ_RMS,$Mismatch_BaseQ_SNR)=&get_statistics_from_hash($mismatch_qual{$target});
		my ($MapQ_StdDev,$MapQ_mean,$MapQ_RMS,$MapQ_SNR)=&get_statistics_from_hash($mapQ{$target});
		my $Match_Bases= ($match_base{$target}->{match_bases})? $match_base{$target}->{match_bases} : 0;
		my $Mismatch_Bases= ($mismatch_base{$target}->{mismatch_bases})? $mismatch_base{$target}->{mismatch_bases} : 0;
		my $Total_Bases = $Match_Bases + $Mismatch_Bases;
		my $Identity = ($Total_Bases)? $Match_Bases / $Total_Bases : 0;
		my $mapped_reads= ($results{$target}->{Mapped_Reads})? $results{$target}->{Mapped_Reads}:0 ;
		
		$results{$target}->{BaseQ_mean}=$BaseQ_mean;
		$results{$target}->{BaseQ_StdDev}=$BaseQ_StdDev;
		$results{$target}->{BaseQ_RMS}=$BaseQ_RMS;
		$results{$target}->{BaseQ_SNR}=$BaseQ_SNR;
		$results{$target}->{Match_BaseQ_mean}=$Match_BaseQ_mean;
		$results{$target}->{Match_BaseQ_StdDev}=$Match_BaseQ_StdDev;
		$results{$target}->{Match_BaseQ_RMS}=$Match_BaseQ_RMS;
		$results{$target}->{Match_BaseQ_SNR}=$Match_BaseQ_SNR;
		$results{$target}->{Mismatch_BaseQ_mean}=$Mismatch_BaseQ_mean;
		$results{$target}->{Mismatch_BaseQ_StdDev}=$Mismatch_BaseQ_StdDev;
		$results{$target}->{Mismatch_BaseQ_RMS}=$Mismatch_BaseQ_RMS;
		$results{$target}->{Mismatch_BaseQ_SNR}=$Mismatch_BaseQ_SNR;
		$results{$target}->{MapQ_mean}=$MapQ_mean;
		$results{$target}->{MapQ_StdDev}=$MapQ_StdDev;
		$results{$target}->{MapQ_RMS}=$MapQ_RMS;
		$results{$target}->{MapQ_SNR}=$MapQ_SNR;
		$results{$target}->{Match_Bases}=$Match_Bases;
		$results{$target}->{Mismatch_Bases}=$Mismatch_Bases;
		$results{$target}->{Total_Bases}=$Total_Bases;
		$results{$target}->{Identity}=$Identity;
		$results{$target}->{Mapped_Reads}=$mapped_reads;
		$results{$target}->{Fraction_Reads}= ($postfilter_reads)? $mapped_reads/$postfilter_reads:0;
		
		$Coverage = ($Coverage/$expectedCoverage > 1)?  1 : $Coverage/$expectedCoverage ;
		$Identity = ($Identity/$expectedIdentity > 1)? 1 : $Identity/$expectedIdentity;
		my $MapQ_normalized = ($MapQ_mean/$expect_bwa_MapQ > 1)? 1 : $MapQ_mean/$expect_bwa_MapQ;
		my $BaseQ_normalized = ($BaseQ_mean/$expect_best_qual > 1)? 1 : $BaseQ_mean/$expect_best_qual;
		
		$quality_calculation = ($Coverage * $coverageWeight * 4) * ($Identity * $identityWeight * 4) * ($BaseQ_normalized * $baseqWeight *4) * ($MapQ_normalized * $mapqWeight * 4);
		
	
		$results{$target}->{Quality_Calculation}=$quality_calculation;
		
		if ($Depth_Mean >= $depth_cutoff && $quality_calculation >= $quality_calculation_cutoff){
			$results{$target}->{Determination}="Positive";
		}elsif($Depth_Mean >= $depth_cutoff && $quality_calculation < $quality_calculation_cutoff){
			$results{$target}->{Determination}="Indeterminate-Quality";
		}elsif($Depth_Mean < $depth_cutoff && $quality_calculation >= $quality_calculation_cutoff){
			$results{$target}->{Determination}="Indeterminate-Depth";
		}else{
			$results{$target}->{Determination}="Negative";
		}

	}
	
	return \%results;
}

sub get_statistics_from_hash {
	# number => count
	my $hash_r=shift;
	
	return (0,0,0,0) if (! $hash_r);
	my $total1 = 0;
	my $sqr_total = 0;
 	my $len = 0;
    # Step 1, find the mean of the numbers
    foreach my $num (keys %{$hash_r}){
    	$total1 += $num * $hash_r->{$num};
    	$sqr_total += ($num**2)*$hash_r->{$num};
    	$len += $hash_r->{$num};
    }
    my $mean1 = $total1 / $len;
	my $rms = sqrt($sqr_total / $len);
	# Step 2, find the mean of the squares of the differences
	# between each number and the mean
	my $total2 = 0;
	foreach my $num (keys %{$hash_r}) {
		$total2 += (($mean1-$num)**2 )* $hash_r->{$num};
	}
	my $mean2 = $total2 / $len;

	# Step 3, standard deviation is the square root of the
	# above mean
	my $std_dev = sqrt($mean2);
	my $snr = ($std_dev)? $mean1 / $std_dev: 0;
	return ($std_dev,$mean1,$rms,$snr);
}

sub get_statistics {
	my($len,@numbers) = @_;
	#Prevent division by 0 error in case you get junk data
	return undef unless(scalar(@numbers));

	my $covered_base=0;

	# Step 1, find the mean of the numbers
	my $total1 = 0;
    	my $sqr_total = 0;
	foreach my $num (@numbers) {
		$covered_base++ if ($num);
		$total1 += $num;
		$sqr_total += $num**2;
	}
	my $mean1 = $total1 / $len;
	my $rms = sqrt($sqr_total / $len);
	# Step 2, find the mean of the squares of the differences
	# between each number and the mean
	my $total2 = 0;
	foreach my $num (@numbers) {
		$total2 += ($mean1-$num)**2;
	}
	my $mean2 = $total2 / $len;

	# Step 3, standard deviation is the square root of the
	# above mean
	my $std_dev = sqrt($mean2);
	my $snr = ($std_dev)? $mean1 / $std_dev: 0;
	my $coverage = $covered_base / $len;
	return ($std_dev,$mean1,$coverage,$rms,$snr);
}

sub get_fasta_seq {
	my $file=shift;
	my $target_r;
	open (my $fh, $file) or die "Cannot open file $file\n";
	$/ = ">";
	while (my $line=<$fh>)
	{
		$line =~ s/\>//g;
		my ($id, @seq) = split /\n/, $line;
		next if (!$id);
		($id) =~ s/^(\S+).*/$1/;
		my $seq = join "", @seq;
		my $len = length($seq);
		$target_r->{$id}->{seq}=$seq;
		$target_r->{$id}->{len}=$len;
	}    
	$/="\n";
	close $fh;
	return $target_r;
}

sub mapped_reads_per_ref {
	my $bam_output = shift;
	my %hash;
	my $total=0;
	open (my $fh, "samtools idxstats $bam_output |") or die "$!\n";
	while (<$fh>)
	{
		chomp;
		my ($id,$len, $mapped,$unmapped)=split /\t/,$_;
		next if ($id eq '*');
		$hash{$id}->{mapped}=$mapped;
		$hash{$id}->{len}=$len;
		$total += $mapped+$unmapped;
	}
	close $fh;
	return (\%hash,$total);
}

sub quality_encoding_coversion 
{  
    # given quality acsii string, offset
    my $q_string=shift;
    my $offset=shift || 33;
    $q_string=~ s/(\S)/(ord($1)-$offset)." "/eg;
    return($q_string);
}

sub Usage 
{
	my $msg=shift;
	print "\n    $msg\n\n" if ($msg);
	print <<"END";
    Usage: perl $0 -o outDir -ref ref.fa  sorted_bamFile
    Version $version
    -o                 Output directory
    -ref               Reference FASTA file
    -c                 Number of CPUs (max: number of target sequecne)
    -q_cutoff          Quality Calculation cutoff [0.8145]
    -depth_cutoff      Depth of coverage cutoff [1000]
    -len_cutoff        Read length filter [100]
    -mode              Paired-End (PE) or Single-End (SE) [default :PE]
    
    Expected value     Expected value for respective quality metric 
    -expectedCoverage  [1]
    -expectedIdentity  [1]
    -expectedBaseQ     [37]
    -expectedMapQ      [60]
    
    Weigth options     Weight for respective metric (sum=1) [double]
    -coverageWeight    [0.25]
    -identityWeight    [0.25]
    -baseqWeight       [0.25]
    -mapqWeight        [0.25]
    
END
    exit;
}
