
# use STAR to align the reads 
star_index=/path/to/star_index/
mkdir resSTAR
foo(){
    local fastq=$1
    fileName=$(basename $fastq)
    fileSuffix=$(echo $fileName | sed s/.fastq.gz//g -)
    STAR --runThreadN 20 --genomeDir $star_index --readFilesCommand zcat \
        --outFileNamePrefix resSTAR/${fileSuffix} \
        --outSAMtype BAM Unsorted --genomeLoad LoadAndKeep \
        --outReadsUnmapped Fastx \
        --readFilesIn /path/to/$fileSuffix'.fastq.gz' >> resSTAR/STAR.log
}
for fastq in $(ls /path/to/rawFastqFiles/*)
do
    foo "$fastq" 
done

# Calculate read counts using featureCounts
mkdir resFCounts
cd resFCounts

gtf_file=/path/to/gtf_file
foo(){
    local bam=$1
    fileName=$(basename $bam)
    fileSuffix=$(echo $fileName | sed s/.bam//g -)
    
    featureCounts -p -T 8 -t gene -g gene_id -a $gtf_file \
-o $fileSuffix.counts $bam
}
for bam in $(ls ../resSTAR/*.bam)
do
    foo "$bam" &
done