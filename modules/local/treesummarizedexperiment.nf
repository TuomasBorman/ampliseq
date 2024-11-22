process TREESUMMARIZEDEXPERIMENT {
    tag "$prefix"
    label 'process_low'

    conda "bioconda::bioconductor-treesummarizedexperiment=2.10.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bioconductor-treesummarizedexperiment%3A2.8.0--r43hdfd78af_0' :
        'bioconductor-treesummarizedexperiment%3A2.8.0--r43hdfd78af_0' }"

    input:
    tuple val(prefix), path(tax_tsv), path(otu_tsv)
    path sam_tsv
    path tree

    output:
    tuple val(prefix), path("*TreeSummarizedExperiment.rds"), emit: rds
    path "versions.yml"                     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def sam_tsv = "\"${sam_tsv}\""
    def otu_tsv = "\"${otu_tsv}\""
    def tax_tsv = "\"${tax_tsv}\""
    def tree    = "\"${tree}\""
    def prefix  = "\"${prefix}\""
    """
    #!/usr/bin/env Rscript

    suppressPackageStartupMessages(library(TreeSummarizedExperiment))

    # Read otu table. It must be in a SimpleList as a matrix where rows
    # represent taxa and columns samples.
    otu_mat  <- read.table($otu_tsv, sep="\\t", header=TRUE, row.names=1)
    otu_mat <- as.matrix(otu_mat)
    assays <- SimpleList(counts = otu_mat)
    # Read taxonomy table. Correct format for it is DataFrame.
    taxonomy_table  <- read.table($tax_tsv, sep="\\t", header=TRUE, row.names=1)
    taxonomy_table <- DataFrame(taxonomy_table)

    # Create TreeSE object. We assume that rownames between taxonomy table
    # and abundance matrix match.
    tse <- TreeSummarizedExperiment(
        assays = assays,
        rowData = taxonomy_table
    )

    # If provided, we add sample metadata as DataFrame object. rownames of
    # sample metadata must match with colnames of abundance matrix.
    if (file.exists($sam_tsv)) {
        sample_meta  <- read.table($sam_tsv, sep="\\t", header=TRUE, row.names=1)
        sample_meta  <- DataFrame(sample_meta)
        colData(tse) <- sample_meta
    }

    # If provided, we add phylogeny. The rownames in abundance matrix must match
    # with node labels in phylogeny.
    if (file.exists($tree)) {
        phylogeny <- read_tree($tree)
        rowTree(tse) <- phylogeny
    }

    saveRDS(tse, file = paste0($prefix, "_TreeSummarizedExperiment.rds"))

    # Version information
    writeLines(c("\\"${task.process}\\":",
        paste0("    R: ", paste0(R.Version()[c("major","minor")], collapse = ".")),
        paste0("    TreeSummarizedExperiment: ", packageVersion("TreeSummarizedExperiment"))),
        "versions.yml"
    )
    """
}
