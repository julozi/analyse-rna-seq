#!/bin/bash

#SBATCH -n 1
#SBATCH --cpus-per-task=8
#SBATCH --partition=fast
#SBATCH --mail-user=pierre.poulain@univ-paris-diderot.fr
#SBATCH --mail-type=ALL

# le script va s'arrêter
# - à la première erreur
# - si une variable n'est pas définie
# - si une erreur est recontrée dans un pipe
set -euo pipefail

# numéro des échantillons à analyser
# les numéros sont entre guillemets et séparés par un espace
# faites en sorte que ces numéros correspondant à VOS échantillons
samples="10 41 7"
# nom du fichier contenant le génome de référence
genome=GCF_000214015.3_version_140606_genomic.fna
# nom du fichier contenant les annotations
annotations=GCF_000214015.3_version_140606_genomic_DUO2.gff

for sample in ${samples}
do
    echo "=============================================================="
    echo "Contrôle qualité - échantillon ${sample}"
    echo "=============================================================="
    srun fastqc HCA-${sample}_R1.fastq.gz

    echo "=============================================================="
    echo "Indexation du génome de référence"
    echo "=============================================================="
    srun bowtie2-build --threads $SLURM_CPUS_PER_TASK ${genome} O_tauri

    echo "=============================================================="
    echo "Alignement des reads sur le génome de référence - échantillon ${sample}"
    echo "=============================================================="
    srun bowtie2 --threads $SLURM_CPUS_PER_TASK -x O_tauri -U HCA-${sample}_R1.fastq.gz -S bowtie-${sample}.sam 2> bowtie-${sample}.out

    echo "=============================================================="
    echo "Conversion en binaire, tri et indexation des reads alignés - échantillon ${sample}"
    echo "=============================================================="
    srun samtools view -@ $SLURM_CPUS_PER_TASK -b bowtie-${sample}.sam > bowtie-${sample}.bam
    srun samtools sort -@ $SLURM_CPUS_PER_TASK bowtie-${sample}.bam -o bowtie-${sample}.sorted.bam
    srun samtools index -@ $SLURM_CPUS_PER_TASK bowtie-${sample}.sorted.bam

    echo "=============================================================="
    echo "Comptage - échantillon ${sample}"
    echo "=============================================================="
    srun htseq-count --stranded=no --type='gene' --idattr='ID' --order=name --format=bam bowtie-${sample}.sorted.bam ${annotations} > count-${sample}.txt

    echo "=============================================================="
    echo "Nettoyage des fichiers inutiles - échantillon ${sample}"
    echo "=============================================================="
    srun rm -f bowtie-${sample}.sam bowtie-${sample}.bam
done

# attente de la fin de toutes les étapes intermédiaires (lancée avec srun)
# avant de cloturer le job
wait
