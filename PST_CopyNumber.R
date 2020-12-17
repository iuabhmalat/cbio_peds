library(dplyr)
library(biomaRt)
library(tidyr)
library(stringr)
library(data.table)

combine_data <- function (filenames) {
  merge_df <- data.table()

  for (i in filenames) {
    # Set df_name to the vendor name
    df <- read.csv(i, sep = ",", header = TRUE, na.strings = c("N/A", "", "unavailable"))

    if(nrow(df)) {
      df$filename <- i
      if (nrow(merge_df) == 0) {
          merge_df <- df
      }
      else {
        if(identical(colnames(merge_df), colnames(df))) {
        merge_df <- rbind(merge_df, df)
        }
        else print("Headers don't match")
      }# Check for headers match
    }
  }
  return(merge_df)
}

ashion <- "c:/Users/abhmalat/OneDrive - Indiana University/cBio_PEDS/data/ashion"
foundation <- "c:/Users/abhmalat/OneDrive - Indiana University/cBio_PEDS/data/foundation"
setwd(ashion)

ensembl <- useMart(host = 'grch37.ensembl.org',
                   biomart = 'ENSEMBL_MART_ENSEMBL',
                   dataset = 'hsapiens_gene_ensembl')

structural_files <- list.files(pattern = '*.structural.csv', recursive = TRUE)

fusion_df <- combine_data(structural_files) %>% dplyr::filter(effect == 'rna_fusion')

fusion_df$Fusion1 <- paste(fusion_df$gene1, fusion_df$gene2, "Fusion")
fusion_df$Fusion2 <- paste(fusion_df$gene2, fusion_df$gene1, "Fusion")

fusion_final <- fusion_df[, c("gene1", "sample_id", "Fusion1", "sequence_type")]
fusion_final <- rbind(fusion_final, setNames(fusion_df[, c("gene2", "sample_id", "Fusion2", "sequence_type")], names(fusion_final)))
colnames(fusion_final) <- c("Hugo_Symbol", "Tumor_Sample_Barcode", "Fusion", "Fusion_Status")

fusion_final$Center <- "unknown"
fusion_final$DNA_support <- "no"
fusion_final$RNA_support <- "yes"
fusion_final$Method <- "unknown"
fusion_final$Frame <- "unknown"

Entrez_Gene_Ids <- getBM(attributes = c("hgnc_symbol", "entrezgene_id"), filters = 'hgnc_symbol',
                         values=fusion_final$Hugo_Symbol, ensembl)
colnames(Entrez_Gene_Ids)[2] <- "Entrez_Gene_Id"

fusion <- left_join(fusion_final, Entrez_Gene_Ids, by = c('Hugo_Symbol' = 'hgnc_symbol'))

fusion$changedSamples <-
samples <- read.csv("data_clinical_sample_formatted.txt", sep = '\t', header = FALSE) %>% dplyr::select('V2')

fusion_exists <- unique(fusion[(fusion$Tumor_Sample_Barcode %in% samples$V2), ])
missing <- unique(fusion[!(fusion$Tumor_Sample_Barcode %in% samples$V2), "Tumor_Sample_Barcode" ])

code <- "c:/Users/abhmalat/OneDrive - Indiana University/cBio_PEDS"
setwd(code)

fusionFile <- "data_fusion.txt"

write.table(fusion, fusionFile, sep="\t", col.names = TRUE, row.names = FALSE,
            quote = FALSE, append = FALSE, na = "NA")

fusionCL <- ("case_lists/cases_sv.txt")

f <- file(fusionCL)
writeLines(c(
 "cancer_study_identifier: PST_PEDS_2020",
 "stable_id: PST_PEDS_2020_sv",
 "case_list_name: RNA Fusion",
 "case_list_description: RNA Fusion",
 paste("case_list_ids: ", paste(unique(fusion$Tumor_Sample_Barcode), collapse = '\t'))
), f
)
close(f)

FusionMetaFile <- "meta_fusion.txt"

f <- file(FusionMetaFile)
writeLines(c(
  "cancer_study_identifier: PST_PEDS_2020",
  "genetic_alteration_type: FUSION",
  "datatype: FUSION",
  "stable_id: FUSION",
  "show_profile_in_analysis_tab: true",
  "profile_name: RNA Fusion",
  "profile_description: RNA Fusion",
  paste("data_filename: ", fusionFile)
), f
)
close(f)
print("RNA Fusion metafile completed")


copynumber_files <- list.files(pattern = '*.copynumber.csv', recursive = TRUE)
somatic_files <- list.files(pattern = '*.somatic.vcf$', recursive = TRUE)
germline_files <- list.files(pattern = '*.germline.vcf$', recursive = TRUE)
