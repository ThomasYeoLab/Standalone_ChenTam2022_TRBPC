# Analyses
** This folder is mainly for CBIG internal use.**

The sub-folders here contain the analyses that we performed after the MMLDA step. Some of the figures appearing in our paper were generated by functions in some folders here. Since many of these folders depend on certain files that are not released publicily, it will be hard for external users to run the code directly. However, we still release the code in the hope that you do not need to start from scratch when performing similar analyses.

----
## What Does Each Folder Do?
1. `10foldCV` (Supplementary Figure 6). This folder contains code for 10 fold cross validation. First, We match the factor orders across folds. Second, we stack factor loading of 10 test foldes together and correlate atrophy loadings with behavior loadings.
2. `association_atrophy_behavior` (Supplementary Figure 11). This folder investigates the associations between atrophy loadings and cognitive loadings among ADNIGO2 A+ MCI participants.
3. `association_factor_tau` (Figure 7). This folder investigates the associations between factor loadings and tau loadings among ADNI23 MCI participants.  
4. `characteristics` (Supplementary Table 3). This folder investigates the associations between latent factors and participants' characteristics (i.e., age, edu, sex, amyloid, APOE e2, APOE e4).
5. `factor_distribution` (Figure 5 and Supplementary Figure 10). This folder generates the triangle plot for ADNIGO2 AD and A+MCI factor compositions.
6. `fdr` This folder does FDR (q = 0.05) correction for all p values in all analyses.
7. `longitudinal_stability` (Figure 6). This folder investigates whether the factor compositions are stable after 1 year.
8. `mean_correlation_map` (Supplementary Figure 9). This folder generates correlation maps between atrophy z score and behavioral mean z score of top 5 scores for each factor in ADNI1 and ADNIGO2 AD subjects.
9. `zscore_hist` (Supplementary Figure 13). This folder plots the histogram of cognitive z score and atrophy z score in ADNIGO2 baseline.
