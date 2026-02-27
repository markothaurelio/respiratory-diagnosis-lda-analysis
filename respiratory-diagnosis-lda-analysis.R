############### Libraries ###############
library(MASS)       # LDA
library(ggplot2)    # Visualizations
library(caret)      # Confusion matrix
library(reshape2)   # Data reshaping
library(ggpubr)     # Normality tests
library(corrplot)   # Correlation plot
library(plotly)     # 3D plot
library(biotools)   # Box's M Test

############### Data Loading ############### 

# This section simply loads the dataset

# Set working directory
setwd("a:/ECU/Data Science Masters/Multivar/major assignment/diseasediag")
# Load the dataset
data <- read.csv("disease_diagnosis.csv") 

############### Data Pre-processing ############### 

# This section contains all code related to pre-processing i.e scaling, data splitting, removing irrelevant data, checking for missing values etc.

# Convert Diagnosis to factor
data$Diagnosis <- factor(data$Diagnosis)

# Used to specify diagnoses included in the LDA model
selected_diagnoses <- c("Pneumonia", "Cold", "Flu", "Bronchitis")

# Used to filter out the the diagnoses not selected above
if (!is.null(selected_diagnoses)) {
  data <- subset(data, Diagnosis %in% selected_diagnoses)
  data$Diagnosis <- droplevels(data$Diagnosis)  # Drop unused levels
}

# Splits Blood_Pressure_mmHg into 'Systolic_BP' and 'Diastolic_BP'
bp_values <- strsplit(as.character(data$Blood_Pressure_mmHg), "/")
data$Systolic_BP <- as.numeric(sapply(bp_values, `[`, 1))
data$Diastolic_BP <- as.numeric(sapply(bp_values, `[`, 2))

# Removes columns not included in the analysis
data <- data[, !(names(data) %in% c("Patient_ID", "Treatment_Plan", "Gender", "Severity", 
                                    "Symptom_1", "Symptom_2", "Symptom_3", "Blood_Pressure_mmHg"))]
# Omits rows with missing values
data <- na.omit(data)

# Split the data into training and test sets (80/20 split)
set.seed(123)  # For reproducibility
train_id <- sample(1:nrow(data), size = ceiling(0.8 * nrow(data)), replace = FALSE)
data_train <- data[train_id, ]
data_test <- data[-train_id, ]


# This scales the numeric data and ensures that only numeric columns are scaled
numeric_columns_train <- sapply(data_train, is.numeric); numeric_columns_train
numeric_columns_test <- sapply(data_test, is.numeric)
data_train[numeric_columns_train] <- scale(data_train[numeric_columns_train])
data_test[numeric_columns_test] <- scale(data_test[numeric_columns_test])

############### Preliminary Analysis ############### 

# This section performs simple analysis on the individual variables 

# Summary of the data 
summary(data_train) 

# Melt the data for visualization
melted_train_data <- melt(data_train, id.vars = "Diagnosis", measure.vars = names(data_train)[numeric_columns_train]); 

# Create boxplots for each numeric variable across diagnosis groups
ggplot(melted_train_data, aes(x = Diagnosis, y = value, fill = Diagnosis)) +
  geom_boxplot() +
  facet_wrap(~ variable, scales = "free", ncol = 2) +
  labs(title = "Boxplots of Numeric Variables Across Diagnosis Groups", x = "Diagnosis Group", y = "Scaled Score") +
  theme_minimal() +
  theme(legend.position = "none")  

# Visualize the correlation matrix
cor_matrix <- cor(data_train[, numeric_columns_train])
corrplot(cor_matrix, method = "color", type = "upper", tl.cex = 0.7, tl.col = "black")

############### Linear Discriminant Analysis (LDA) - Predict and Evaluate on Train Data ############### 

# This section performs Linear Discriminant Analysis on the training variables

# Train the LDA model on the training data
lda_model <- lda(Diagnosis ~ ., data = data_train)

# Print the LDA model
print(lda_model)

# Predictions on training data using LDA
pred_train <- predict(lda_model, data_train)

# Confusion matrix for the training data
conf_matrix_train <- confusionMatrix(pred_train$class, data_train$Diagnosis)
print(conf_matrix_train)

# Classification table for training data
tab_train <- table(pred_train$class, data_train$Diagnosis)
print(tab_train)

############### Linear Discriminant Analysis (LDA) - Predict and Evaluate on Test Data ############### 

# This section performs Linear Discriminant Analysis on the test variables

# Predict the group labels for the test data
pred_test <- predict(lda_model, newdata = data_test)

# Confusion matrix for the test data
conf_matrix_test <- confusionMatrix(pred_test$class, data_test$Diagnosis)
print(conf_matrix_test)

# Classification table for test set
tab_test <- table(pred_test$class, data_test$Diagnosis)
print(tab_test)

############### Assumption Checks ############### 

# This section performs the assumption checks for Linear Discriminant Analysis 

# Equality of covariance matrices check
box_m_result <- boxM(data_train[, numeric_columns_train], data_train$Diagnosis)
print(box_m_result)

# Normality checks
lda_df <- data.frame(LD1 = pred_train$x[, 1], LD2 = pred_train$x[, 2],LD3 = pred_train$x[, 3], Group = data_train$Diagnosis); 
# Shapiro-Wilk test for LD1 normality for each group
shapiro_ld1 <- by(lda_df$LD1, lda_df$Group, shapiro.test)
print("Shapiro-Wilk Test for LD1:")
print(shapiro_ld1)
# Shapiro-Wilk test for LD2 normality for each group
shapiro_ld2 <- by(lda_df$LD2, lda_df$Group, shapiro.test)
print("Shapiro-Wilk Test for LD2:")
print(shapiro_ld2)
# Shapiro-Wilk test for LD2 normality for each group
shapiro_ld3 <- by(lda_df$LD3, lda_df$Group, shapiro.test)
print("Shapiro-Wilk Test for LD3:")
print(shapiro_ld3)

################################## Validation Plots ##################################

# This section generates validation plots to assist in interpreting the results of the Linear Discriminant Analysis

# Add the linear discriminant values to the training data
data_train$LD1 <- pred_train$x[, 1]
data_train$LD2 <- pred_train$x[, 2]
data_train$LD3 <- pred_train$x[, 3]  

# 3D scatter plot using plotly
plot_ly(data_train, x = ~LD1, y = ~LD2, z = ~LD3, color = ~Diagnosis, colors = c('#636EFA','#EF553B','#00CC96','#AB63FA')) %>%
  add_markers() %>%
  layout(title = "3D Scatter Plot of Linear Discriminants",
           scene = list(xaxis = list(title = 'LD1'),
                        yaxis = list(title = 'LD2'),
                        zaxis = list(title = 'LD3')))

# 2D scatter plot using plotly
plot_ly(data_train, x = ~LD1, y = ~LD2, color = ~Diagnosis, colors = c('#636EFA','#EF553B','#00CC96','#AB63FA')) %>%
  add_markers() %>%
  layout(title = "Biplot of LD1 and LD2",
         xaxis = list(title = 'LD1'),
         yaxis = list(title = 'LD2'))

# Density plot of the first linear discriminant 
ggplot(data_train, aes(x = LD1, fill = Diagnosis)) +
  geom_density(alpha = 0.5) +
  scale_fill_manual(values = c("Bronchitis" = '#636EFA', 
                               "Cold" = '#EF553B', 
                               "Flu" = '#00CC96', 
                               "Pneumonia" = '#AB63FA')) + 
  labs(title = "Density Plot of LD1", x = "LD1", y = "Density") +
  theme_minimal()


# Boxplot of LD1 across diagnosis groups
ggplot(data_train, aes(x = Diagnosis, y = LD1, fill = Diagnosis)) +
  geom_boxplot() +
  labs(title = "Boxplot of LD1 Across Diagnosis Groups", x = "Diagnosis Group", y = "LD1") +
  theme_minimal() +
  theme(legend.position = "none")

