//
// Uncompress and prepare reference genome files
//

include { GATK4_CREATESEQUENCEDICTIONARY }    from '../../modules/nf-core/modules/gatk4/createsequencedictionary/main' //addParams(options: params.genome_options)
include { GET_CHROM_SIZES }                   from '../../modules/local/get_chrom_sizes'                               //addParams(options: params.genome_options)
include { GFFREAD }                           from '../../modules/nf-core/modules/gffread/main'                        //addParams(options: params.gffread_options)
include { GTF2BED }                           from '../../modules/local/gtf2bed'                                       //addParams(options: params.genome_options)
include { GUNZIP as GUNZIP_FASTA }            from '../../modules/nf-core/modules/gunzip/main'                         //addParams(options: params.genome_options)
include { GUNZIP as GUNZIP_GENE_BED }         from '../../modules/nf-core/modules/gunzip/main'                         //addParams(options: params.genome_options)
include { GUNZIP as GUNZIP_GFF }              from '../../modules/nf-core/modules/gunzip/main'                         //addParams(options: params.genome_options)
include { GUNZIP as GUNZIP_GTF }              from '../../modules/nf-core/modules/gunzip/main'                         //addParams(options: params.genome_options)
include { SAMTOOLS_FAIDX }                    from '../../modules/nf-core/modules/samtools/faidx/main'                 //addParams(options: params.genome_options)
include { STAR_GENOMEGENERATE }               from '../../modules/nf-core/modules/star/genomegenerate/main'            //addParams(options: params.star_index_options)
include { UNTAR as UNTAR_STAR_INDEX }         from '../../modules/nf-core/modules/untar/main'                          //addParams(options: params.star_untar_options)


workflow PREPARE_GENOME {
    take:
    prepare_tool_indices

    main:

    ch_versions = Channel.empty()

    //
    // Uncompress genome fasta file if required
    //
    if (params.fasta.endsWith('.gz')) {
        ch_fasta = (GUNZIP_FASTA ( params.fasta ).gunzip)
        ch_versions = ch_versions.mix(GUNZIP_FASTA.out.versions)
    } else {
        ch_fasta = file(params.fasta)
    }

    //
    // Uncompress GTF annotation file or create from GFF3 if required
    //

    ch_gffread_version = Channel.empty()
    if (params.gtf) {
        if (params.gtf.endsWith('.gz')) {
            ch_gtf = GUNZIP_GTF ( params.gtf ).gunzip
            ch_versions = ch_versions.mix(GUNZIP_GTF.out.versions)
        } else {
            ch_gtf = file(params.gtf)
        }
    } else if (params.gff) {
        if (params.gff.endsWith('.gz')) {
            ch_gff = GUNZIP_GFF ( params.gff ).gunzip
            ch_versions = ch_versions.mix(GUNZIP_GFF.out.versions)
        } else {
            ch_gff = file(params.gff)
        }
        ch_gtf = GFFREAD ( ch_gff ).gtf
        ch_versions = ch_versions.mix(GFFREAD.out.versions)
    }

    //
    // Uncompress gene BED annotation file or create from GTF if required
    //
    if (params.gene_bed) {
        if (params.gene_bed.endsWith('.gz')) {
            ch_gene_bed = GUNZIP_GENE_BED ( params.gene_bed ).gunzip
            ch_versions = ch_versions.mix(GUNZIP_GENE_BED.out.versions)
        } else {
            ch_gene_bed = file(params.gene_bed)
        }
    } else {
        ch_gene_bed = GTF2BED ( ch_gtf ).bed
        ch_versions = ch_versions.mix(GTF2BED.out.versions)
    }

    // Index the genome fasta
    ch_fasta_fai = Channel.empty()
    if (params.fasta_fai) ch_fasta_fai = file(params.fasta_fai)
    else                  ch_fasta_fai = SAMTOOLS_FAIDX(ch_fasta).fai

    // Create dictionary file for the genome fasta
    ch_fasta_dict = Channel.empty()
    if (params.dict) ch_fasta_dict = file(params.dict)
    else                   ch_fasta_dict = GATK4_CREATESEQUENCEDICTIONARY(ch_fasta).dict

    //
    // Create chromosome sizes file
    //
    ch_chrom_sizes = GET_CHROM_SIZES ( ch_fasta ).sizes

    //
    // Uncompress STAR index or generate from scratch if required
    //
    ch_star_index       = Channel.empty()
    ch_fasta_for_index  = Channel.empty()

    if ('star' in prepare_tool_indices) {
        if (params.star_index) {
            if (params.star_index.endsWith('.tar.gz')) {
                ch_star_index = UNTAR_STAR_INDEX ( params.star_index ).untar
                ch_versions   = ch_versions.mix(UNTAR_STAR_INDEX.out.versions)
            } else {
                ch_star_index = Channel.fromPath(params.star_index)
            }

            // Get the version of the index and branch into valid or invalid
            ch_star_index.branch { dir ->
                valid_index: getIndexVersion(dir) == '2.7.4a'
                            return dir
                invalid_index: getIndexVersion(dir) != '2.7.4a'
                            return ch_fasta
            }.set{result}

            ch_star_index      = result.valid_index
            ch_fasta_for_index = result.invalid_index
        }
        else {
            ch_fasta_for_index = ch_fasta
        }

            ch_star_index_optional = STAR_GENOMEGENERATE (ch_fasta_for_index,ch_gtf).index
            ch_versions            = ch_versions.mix(STAR_GENOMEGENERATE.out.versions)

            ch_star_index          = ch_star_index.mix(ch_star_index_optional)
    }

    emit:
    fasta            = ch_fasta            // path: genome.fasta
    fai              = ch_fasta_fai        // path: genome.fasta.fai
    dict             = ch_fasta_dict       // path: genome.fasta.dict
    gtf              = ch_gtf              // path: genome.gtf
    gene_bed         = ch_gene_bed         // path: gene.bed
    chrom_sizes      = ch_chrom_sizes      // path: genome.sizes
    star_index       = ch_star_index       // path: star/index/
    versions         = ch_versions.ifEmpty(null) // channel: [ versions.yml ]
}

def getIndexVersion( index_path ) {
    genomeParameters = new File("$index_path/genomeParameters.txt")
    if ( genomeParameters.exists() ) {
        for(line: genomeParameters.readLines()){
            if(line.startsWith("versionGenome")){
                return line.split("\t")[1].trim()
            }
        }
    }
}
