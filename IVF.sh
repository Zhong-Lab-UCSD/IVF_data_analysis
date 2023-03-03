# perform bcl to fastq
bcl2fastq -p 24 \
    --runfolder-dir /path/to/rawBCLFile \
    --output-dir /outputDir/ \
    --use-bases-mask y51,i8y8,y51 --create-fastq-for-index-reads \
    --sample-sheet /path/to/sampleSheet.csv \
    --minimum-trimmed-read-length 0 \
    --mask-short-adapter-reads 0 \
    --tiles s_1

# use fastqc as quality check
mkdir resFastQC
fastqc -o resFastQC $(ls /path/to/Mate1.fastq.gz)
fastqc -o resFastQC $(ls /path/to/Mate2.fastq.gz)

# rename fastq and index (UMI)
mkdir fastqInput indexInput
inputPath=/path/to/rawFastq
outputPath=fastqInput
foo(){
    local M1=$1
    fileName=$(basename $M1)
    fileSuffix=$(echo $fileName | sed s/_L001_R1_001.fastq.gz//g -)
    cp $inputPath/$fileSuffix'_L001_R1_001.fastq.gz' $outputPath/$fileSuffix'.M1.fastq.gz'
    cp $inputPath/$fileSuffix'_L001_R3_001.fastq.gz' $outputPath/$fileSuffix'.M2.fastq.gz'
}
for M1 in $(ls $inputPath/*)
do
    foo "$M1" &
done
foo(){
    local M1=$1
    fileName=$(basename $M1)
    fileSuffix=$(echo $fileName | sed s/_L002_R1_001.fastq.gz//g -)
    cp $inputPath/$fileSuffix'_L002_R1_001.fastq.gz' $outputPath/$fileSuffix'.M1.fastq.gz'
    cp $inputPath/$fileSuffix'_L002_R3_001.fastq.gz' $outputPath/$fileSuffix'.M2.fastq.gz'
}
for M1 in $(ls $inputPath/IVFS*_L002_R1_001.fastq.gz)
do
    foo "$M1" &
done

inputPath=rawFastq
outputPath=indexInput
foo(){
    local M2=$1
    fileName=$(basename $M2)
    fileSuffix=$(echo $fileName | sed s/_L001_R2_001.fastq.gz//g -)
    cp $inputPath/$fileSuffix'_L001_R2_001.fastq.gz' $outputPath/$fileSuffix'_dupInd.fastq.gz'
}
for M2 in $(ls $inputPath/*)
do
    foo "$M2" &
done
foo(){
    local M2=$1
    fileName=$(basename $M2)
    fileSuffix=$(echo $fileName | sed s/_L002_R2_001.fastq.gz//g -)
    cp $inputPath/$fileSuffix'_L002_R2_001.fastq.gz' $outputPath/$fileSuffix'_dupInd.fastq.gz'
}
for M2 in $(ls $inputPath/IVFS*_L002_R2_001.fastq.gz)
do
    foo "$M2" &
done

# use Trimmomatic to trim the leading and trailing bases of reads
raw_fastq_path=fastqInput
mkdir trim_fastq
mkdir unpaired_fastq
trimmomaticPath=/path/to/Trimmomatic-0.39
foo(){
    local raw_fastq=$1
    fileName=$(basename $raw_fastq)
    fileSuffix=$(echo $fileName | sed s/.M1.fastq.gz//g -)

    java -jar $trimmomaticPath/trimmomatic-0.39.jar PE -phred33 -threads 10 \
        $raw_fastq_path/$fileSuffix'.M1.fastq.gz' \
        $raw_fastq_path/$fileSuffix'.M2.fastq.gz' \
        trim_fastq/$fileSuffix'.M1.fastq.gz' \
        unpaired_fastq/$fileSuffix'.M1.fastq.gz' \
        trim_fastq/$fileSuffix'.M2.fastq.gz' \
        unpaired_fastq/$fileSuffix'.M2.fastq.gz' \
        ILLUMINACLIP:$trimmomaticPath/adapters/TruSeq3-SE-wG.fa:2:30:10:2:keepBothReads LEADING:3 TRAILING:3 \
        SLIDINGWINDOW:4:15 MINLEN:10 > trim_fastq/trimmomatic_$fileSuffix'.log'
}
for raw_fastq in $(ls $raw_fastq_path/*.M1.fastq.gz)
do
    foo "$raw_fastq" &
done

# use STAR to align the reads 
star_index=/path/to/star_index/
mkdir resSTAR
foo(){
    local trim_fastq=$1
    fileName=$(basename $trim_fastq)
    fileSuffix=$(echo $fileName | sed s/.M1.fastq.gz//g -)
    STAR --runThreadN 20 --genomeDir $star_index --readFilesCommand zcat \
        --outFileNamePrefix resSTAR/${fileSuffix} \
        --outSAMtype BAM Unsorted --genomeLoad LoadAndKeep \
        --outReadsUnmapped Fastx \
        --readFilesIn /path/to/$fileSuffix'.M1.fastq.gz' /path/to/$fileSuffix'.M2.fastq.gz' >> resSTAR/STAR.log
}
for trim_fastq in $(ls /path/to/mate1Reads/*M1.fastq.gz)
do
    foo "$trim_fastq" 
done

# Deduplication based on UMI using nudup.py
nudup_path=/path/to/nudup.py
index_path=/path/to/UMIIndex
mkdir resDedup
foo(){
    local bam=$1
    fileName=$(basename $bam)
    fileSuffix=$(echo $fileName | sed s/Aligned.out.bam//g -)
    mkdir tmp'_'$fileSuffix
    
    python $nudup_path -f $index_path/$fileSuffix'_dupInd.fastq.gz' -o resDedup/$fileSuffix \
        -s 8 -l 8 -2 -T tmp'_'$fileSuffix --rmdup-only \
        resSTAR/$fileSuffix'Aligned.out.bam'
    rm -rf tmp'_'$fileSuffix
}
for bam in $(ls resSTAR/*Aligned.out.bam)
do
    foo "$bam"
done

# Calculate read counts using featureCounts
mkdir resFCounts
cd resFCounts

gtf_file=/path/to/gtf_file
foo(){
    local bam=$1
    fileName=$(basename $bam)
    fileSuffix=$(echo $fileName | sed s/.sorted.dedup.bam//g -)
    
    featureCounts -p -T 8 -t gene -g gene_id -a $gtf_file \
-o $fileSuffix.counts $bam
}
for bam in $(ls ../resDedup/*.bam)
do
    foo "$bam" &
done



