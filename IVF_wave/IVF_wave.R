# define function that capture genes from specific stages
VennCalc <- function(mat, vect){
  vect <- (vect*(-1) + 1)/2
  for(i in 1:length(vect)){
    if(vect[i]){
      mat[,i] <- 1-mat[,i]
    }
  }
  return(rownames(mat[rowSums(mat) == ncol(mat),]))
}

# load data
sharedGenes <- read.table('stageGenes', row.names = 1, header = T)

# Consistent genes
consistent_genes <- VennCalc(sharedGenes, c(1,1,1,1,1))

# Oocyte-specific genes
oocyte_specific_genes <- VennCalc(sharedGenes, c(-1,1,-1,-1,1))

# Maternal genes
maternal_genes <- c(VennCalc(sharedGenes, c(1,1,-1,1,1)),VennCalc(sharedGenes, c(1,1,-1,-1,1)))

# Early zygotic genes
early_zygotic_genes <- c(VennCalc(sharedGenes, c(1,1,-1,-1,-1)), VennCalc(sharedGenes, c(1,1,-1,1,-1)))

# Late zygotic genes
late_zygotic_genes <- c(VennCalc(sharedGenes, c(-1,1,-1,-1,-1)), VennCalc(sharedGenes, c(-1,1,-1,-1,1)))

# Post-compaction genes
post_compaction_genes <- c(VennCalc(sharedGenes, c(1,1,-1,1,1)), VennCalc(sharedGenes, c(1,1,-1,1,-1)))