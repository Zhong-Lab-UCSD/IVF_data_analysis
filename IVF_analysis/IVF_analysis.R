# load package
library(randomForest)
library(pROC)

# load data
pValues <- read.table('pValues', row.names = 1, header = T)
pValues <- pValues[!is.na(pValues$pValue120),]
developmentScore <- read.table('developmentScore', header = T)

normalized_count <- read.table('IVF_NC.tsv', row.names = 1, header = T, sep = '\t', check.names=FALSE)
normalized_count <- normalized_count[,-1]
metaInfo <- xlsx::read.xlsx('Table-S-Sample-MetaInfo.xlsx', 1)

normalized_count <- normalized_count[,metaInfo$Sample.ID[metaInfo$Collection.time..h. == '120' & metaInfo$Arrest.status != 'N/A']]

# perform random sub-sampling
set.seed(125)
thVect <- c(0.005,0.008,seq(0.01,0.04,0.004),seq(0.04,0.09,0.02),seq(0.1,0.5,0.05))
num <- rep(0,length(c(0.005,0.008,seq(0.01,0.04,0.004),seq(0.04,0.09,0.02),seq(0.1,0.5,0.05))))
aveAUC <- rep(0,length(c(0.01,seq(0.05,0.5,0.05))))
for(th in thVect){
  t <- rownames(pValues[pValues$pValue120 < th,])
  df <- normalized_count[t,]
  df <- df[rowSums(df > 0) > ncol(df) * 0.7,]
  num[which(thVect == th)] <- nrow(df)
  df <- as.data.frame(t(df))
  df$developmentScore <- developmentScore$developmentScore[match(rownames(df), developmentScore$SampleID)]
  df$developmentScore_cat <- as.factor(as.numeric(df$developmentScore >=25))
  df <- df[,-which(colnames(df) == 'developmentScore')]
  colnames(df)[grep('-',colnames(df))] <- gsub('-','_',colnames(df)[grep('-',colnames(df))])
  
  ROC_rf_auc <- rep(0,100)
  for(i in 1:100){
    ind_1 <- sample(which(df$developmentScore_cat == 1), nrow(df)/2*0.7, replace = F)
    ind_0 <- sample(which(df$developmentScore_cat == 0), length(ind_1), replace = F)
    ind <- c(ind_1,ind_0)
    train <- df[ind,]
    test <- df[-ind,]
    
    rf <- randomForest(developmentScore_cat~., data=train, proximity=TRUE)
    predictions <- as.data.frame(predict(rf, test, type = "prob"))
    ROC_rf <- roc(test$developmentScore_cat, predictions[,2])
    ROC_rf_auc[i] <- auc(ROC_rf)
  }
  aveAUC[which(thVect == th)] <- mean(ROC_rf_auc)
}
df <- data.frame(aveAUC = aveAUC, numberOfFeatures = num)

# generate Figure 3C
ggplot(df,aes(x = numberOfFeatures, y = aveAUC)) + 
  geom_point(size = 2) +
  ylim(c(0,1)) + xlab('Number of features') + ylab('Average AUC') +
  scale_x_continuous(trans = 'log2', breaks=c(10, 100, 1000)) +
  theme(panel.border = element_blank(),
        panel.grid.minor = element_blank(),
        axis.line = element_line(colour = "black"),
        axis.text = element_text(size = 17),
        axis.title = element_text(size = 22)) 
