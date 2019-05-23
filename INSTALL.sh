#!/usr/bin/env bash

set -e # Exit as soon as any line in the bash script fails

ROOTDIR=$( cd $(dirname $0) ; pwd -P ) # path to main TargetNGS directory

echo
exec &> >(tee -a  install.log)
exec 2>&1 # copies stderr onto stdout

# create a directory where all dependencies will be installed
cd $ROOTDIR

export PATH="$ROOTDIR/ext/miniconda/bin:$ROOTDIR/ext:$PATH"
export PERL5LIB="$ROOTDIR/ext/lib:$PERL5LIB"
export R_LIBS="$ROOTDIR/ext/lib/R_libs"
minicondaPATH=$ROOTDIR/ext/miniconda

mkdir -p $R_LIBS
mkdir -p $minicondaPATH

# minimum tools version
R_VER=3.3.2
bowtie2_VER=2.2.8
bwa_VER=0.7.15
samtools_VER=1.9
plotly_VER=4.5.6
Parallel_ForkManager_VER=1.19
phantomjs_VER=2.1.1
minimap2_VER=2.10

install_minimap2()
{
echo "--------------------------------------------------------------------------
		Installing minimap2 v$minimap2_VER
--------------------------------------------------------------------------------
"
conda install --yes -p $minicondaPATH -c bioconda minimap2==2.10
echo "
--------------------------------------------------------------------------------
		minimap2 v$minimap2_VER installed
--------------------------------------------------------------------------------
"

}

install_R()
{
echo "------------------------------------------------------------------------------
               Installing R $R_VER
------------------------------------------------------------------------------
"
conda install --yes -p $minicondaPATH -c r r-base="$R_VER"
echo "
------------------------------------------------------------------------------
		R $R_VER Installed
------------------------------------------------------------------------------
"
}

install_bowtie2()
{
echo "--------------------------------------------------------------------------
                           installing bowtie2 v$bowtie2_VER
--------------------------------------------------------------------------------
"
conda install --yes -p $minicondaPATH -c bioconda bowtie2=$bowtie2_VER
echo "
------------------------------------------------------------------------------
                           bowtie2 v$bowtie2_VER installed
------------------------------------------------------------------------------
"
}

install_bwa()
{
echo "------------------------------------------------------------------------------
                           Downloading bwa v$bwa_VER
------------------------------------------------------------------------------
"
conda install --yes -p $minicondaPATH -c bioconda bwa=$bwa_VER
echo "
------------------------------------------------------------------------------
                           bwa v$bwa_VER installed
------------------------------------------------------------------------------
"
}

install_samtools()
{
echo "--------------------------------------------------------------------------
                           Downloading samtools v$samtools_VER
--------------------------------------------------------------------------------
"
conda install --yes -p $minicondaPATH -c bioconda samtools=$samtools_VER
echo "
--------------------------------------------------------------------------------
                           samtools v$samtools_VER installed
--------------------------------------------------------------------------------
"
}

install_xlsx2csv()
{
echo "--------------------------------------------------------------------------
                           Downloading xlsx2csv
--------------------------------------------------------------------------------
"
pip install --install-option="--prefix=$minicondaPATH" xlsx2csv
echo "
--------------------------------------------------------------------------------
                           xlsx2csv installed
--------------------------------------------------------------------------------
"
}

install_phantomjs()
{
echo "--------------------------------------------------------------------------
                           Downloading phantomjs v$phantomjs_VER
--------------------------------------------------------------------------------
"
conda install --yes -p $minicondaPATH -c javascript phantomjs=$phantomjs_VER
echo "
--------------------------------------------------------------------------------
                           phantomjs v$phantomjs_VER installed
--------------------------------------------------------------------------------
"
}

install_cpanm()
{
echo "--------------------------------------------------------------------------
                           Installing cpanm
--------------------------------------------------------------------------------
"
curl -k -L https://cpanmin.us/ -o ext/cpanm
chmod a+x ext/cpanm;
echo "
--------------------------------------------------------------------------------
                           cpanm installed
--------------------------------------------------------------------------------
"
}

install_miniconda()
{
echo "--------------------------------------------------------------------------
                           downloading miniconda
--------------------------------------------------------------------------------
"
if [[ "$OSTYPE" == "darwin"* ]]
then
{

  curl -o ext/miniconda.sh https://repo.continuum.io/miniconda/Miniconda2-4.2.12-MacOSX-x86_64.sh

}
else
{  

  curl -o ext/miniconda.sh https://repo.continuum.io/miniconda/Miniconda2-4.2.12-Linux-x86_64.sh 
}
fi

chmod +x ext/miniconda.sh
./ext/miniconda.sh -b -p $minicondaPATH -f
export PATH=$ROOTDIR/ext/miniconda/bin:$PATH

}


checkSystemInstallation()
{
    IFS=:
    for d in $PATH; do
      if test -x "$d/$1"; then return 0; fi
    done
    return 1
}

checkLocalInstallation()
{
    IFS=:
    for d in $minicondaPATH/bin; do
      if test -x "$d/$1"; then return 0; fi
    done
    return 1
}

checkPerlModule()
{
   perl -e "use lib \"$ROOTDIR/ext/lib/perl5\"; use $1;"
   return $?
}


####### MAIN #######


if ( checkSystemInstallation conda )
then
	conda_installed_VER=`conda --version 2>&1|perl -nle 'print $& if m{(\d+\.\d+\.\d+)}'`;
  	echo " - found conda $conda_installed_VER"
else
 	install_miniconda
fi



if ( checkSystemInstallation R )
then
	R_installed_VER=`R --version | perl -nle 'print $& if m{version (\d+\.\d+\.\d+)}'`;
	if  ( echo $R_installed_VER $R_VER| awk '{if($2>=$3) exit 0; else exit 1}' )
	then
    	echo " - found R $R_installed_VER"
    else
    	install_R
    fi
else
    install_R
fi

# install R plotly packages
Rscript --no-init-file -e "if('plotly' %in% rownames(installed.packages()) == TRUE){packageVersion('plotly');}"  | awk '{print " - found plotly "$2}'
Rscript --no-init-file -e "if('plotly' %in% rownames(installed.packages()) == FALSE){install.packages('plotly',repos='https://cran.r-project.org')}";
# install R webshot packages
Rscript --no-init-file -e "if('webshot' %in% rownames(installed.packages()) == TRUE){packageVersion('webshot');}"  | awk '{print " - found webshot "$2}'
Rscript --no-init-file -e "if('webshot' %in% rownames(installed.packages()) == FALSE){install.packages('webshot',repos='https://cran.r-project.org')}";
# install R shiny packages
Rscript --no-init-file -e "if('shiny' %in% rownames(installed.packages()) == TRUE){packageVersion('shiny');}"  | awk '{print " - found shiny "$2}'
Rscript --no-init-file -e "if('shiny' %in% rownames(installed.packages()) == FALSE){install.packages('shiny',repos='https://cran.r-project.org')}";
# install R DT packages
Rscript --no-init-file -e "if('DT' %in% rownames(installed.packages()) == TRUE){packageVersion('DT');}"  | awk '{print " - found DT "$2}'
Rscript --no-init-file -e "if('DT' %in% rownames(installed.packages()) == FALSE){install.packages('DT',repos='https://cran.r-project.org')}";


if ( checkSystemInstallation phantomjs )
then
	phantomjs_installed_VER=`phantomjs -v`;
	if  ( echo $phantomjs_installed_VER $phantomjs_VER| awk '{if($1>=$2) exit 0; else exit 1}' )
	then
		echo " - found phantomjs $phantomjs_installed_VER"
	else
		install_phantomjs
	fi
else
  install_phantomjs
fi


#if ( checkSystemInstallation bowtie2 )
#then
#	bowtie_installed_VER=`bowtie2 --version | grep bowtie | perl -nle 'print $& if m{version \d+\.\d+\.\d+}'`;
#	if  ( echo $bowtie_installed_VER $bowtie2_VER| awk '{if($2>=$3) exit 0; else exit 1}' )
#	then
#		echo " - found bowtie2 $bowtie_installed_VER"
#	else
#		install_bowtie2
#	fi
#else
#	install_bowtie2	
#fi

if ( checkSystemInstallation bwa )
then
	bwa_installed_VER=`bwa 2>&1| grep 'Version'  | perl -nle 'print $& if m{Version: \d+\.\d+\.\d+}'`;
	if  ( echo $bwa_installed_VER $bwa_VER | awk '{if($2>=$3) exit 0; else exit 1}' )
	then
		echo " - found BWA $bwa_installed_VER"
	else
		install_bwa
	fi
else
  install_bwa
fi

if ( checkSystemInstallation minimap2 )
then
	minimap2_installed_VER=`minimap2 --version |  perl -nle 'print $1 if m{(\d+\.\d+\.*\d*)}'`;
	if  ( echo $minimap2_installed_VER $minimap2_VER| awk '{if($1>=$2) exit 0; else exit 1}' )
	then
		echo " - found minimap2 $minimap2_installed_VER"
	else
		install_minimap2
	fi
else
	install_minimap2
fi

if ( checkSystemInstallation samtools )
then
	samtools_installed_VER=`samtools 2>&1| grep 'Version'|perl -nle 'print $& if m{Version: \d+\.\d+.\d+}'`;
	if [ -z "$samtools_installed_VER" ]
	then 
		samtools_installed_VER=`samtools 2>&1| grep 'Version'|perl -nle 'print $& if m{Version: \d+\.\d+}'`; 
	fi
	
	if  ( echo $samtools_installed_VER $samtools_VER| awk '{if($2>=$3) exit 0; else exit 1}' )
	then
		echo " - found samtools $samtools_installed_VER"
	else
		install_samtools
	fi
else
  install_samtools
fi

if ( checkSystemInstallation xlsx2csv )
then
	echo " - found xlsx2csv"
else
	install_xlsx2csv
fi

if ( checkSystemInstallation cpanm )
then
	cpanm_installed_VER=`cpanm --version|grep cpanm |perl -nle 'print $& if m{(\d+\.\d+)}'`;
	echo " - found cpanm $cpanm_installed_VER"
else
	install_cpanm
fi

if ( checkPerlModule Parallel::ForkManager )
then
	Parallel_ForManager_installed_VER=`perl -e "use lib '$ROOTDIR/ext/lib/perl5'; use Parallel::ForkManager; print \\\$Parallel::ForkManager::VERSION;"`
	echo " - found Parallel::ForkManager $Parallel_ForManager_installed_VER"
else  
	echo "Installing Perl dependencies..."
	( set -xe;
		perl -MParallel::ForkManager -e 1 > /dev/null 2>&1           || cpanm -v --notest -l ext Parallel::ForkManager;
	)
fi



echo "
==============================================
	TARGETEDNGS installed successfully
==============================================

	./DETEQT  -h

for usage.
Read the README for more information!
Thanks!
";
