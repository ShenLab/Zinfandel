#!/bin/sh
# Author: Ye Liu
#
# Converts SOLiD reads, together with their quality files, into .fastq format to run through maq.
# Inputs: ShortName, OutputName, FastaRef, OutputDir
### NOTE: 
### This version is for very large files; it merges maps multiple times to avoid opening too many 
### files at once if/when SOLiD read files' size increases.

echo "Converting SOLiD reads to fastq ...";
#need to fix the following line- you cant predict where the script will be.
perl /home/yeliu/Maq/Maq/maq-0.6.5_i686-linux/solid2fastq.pl $1 $2;
echo "Done.";

gunzip $2.read1.fastq.gz;
gunzip $2.read2.fastq.gz;

echo "Converting reference files ...";
#if converted reference files already exist, the script will assume that they
#match their names and use them instead of converting again.
if [ ! -e $3.csfa ]
then
    maq fasta2csfa $3 > $3.csfa;
fi
if [ ! -e $3.csbfa ]
then
    maq fasta2bfa $3.csfa $3.csbfa;
fi
if [ ! -e $3.bfa ]
then
    maq fasta2bfa $3 $3.bfa;
fi
echo "Done.";

#breaks into chunks...
echo "Breaking files into smaller chunks ...";
chunks=`perl /home3/yeliu/atlas-cnv/atlas-cnv/Mapping/BreakChunks.pl $2 $4`;
echo "Done.";

for ((i=1; i<=chunks; i++))
do
    echo "Processing $4$2.read1.$i.fastq ...";
    maq fastq2bfq $4$2.read1.$i.fastq $4$2.read1.$i.bfq;
    echo "Processing $4$2.read2.$i.fastq ...";
    maq fastq2bfq $4$2.read2.$i.fastq $4$2.read2.$i.bfq;
    maq map -c $4$2.part$i.map $3.csbfa $4$2.read1.$i.bfq $4$2.read2.$i.bfq 2>>$4$2.run.txt;
done

#see the readme file for why sqrt is used here.
nMaps=`perl -e 'print int(sqrt($ARGV[0]))' $chunks`;

for ((i=55; i<=$chunks; i=$((i + $nMaps))))
do
    partmaps=();
    j=0;
    max=$((nMaps - 1));

    if ((($chunks - $i) <= $nMaps))
    then
	max=$((chunks - i));
    fi

    while (($j <= $max))
    do
	partmaps="$partmaps $4$2.part$((i+j)).map";
	j=$((j + 1));
    done
    echo "Merging maps ... $partmaps";
    maq mapmerge $4$2.$i.map $partmaps;
    maps="$maps $4$2.$i.map";
done

echo "Merging maps ... $maps";
maq mapmerge $4$2.all.map $maps;
echo "Done.";
    
echo "Assembling consensus files ...";
maq assemble $4$2.cns.cns $3.bfa $4$2.all.map 2>>$4$2.run.txt;
maq cns2snp $4$2.cns.cns > $4$2.cns.snp;
maq.pl SNPfilter $4$2.cns.snp > $4$2.cns.filtered.snp;
maq cns2fq $4$2.cns.cns > $4$2.cns.fq;
maq indelpe $3.bfa $4$2.all.map > $4$2.indelpe;
echo "Done.";
