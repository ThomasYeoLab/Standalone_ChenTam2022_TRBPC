#!/bin/bash

# Written by Nanbo Sun and CBIG under MIT license: https://github.com/ThomasYeoLab/CBIG/blob/master/LICENSE.md

###########################################
# Usage and Reading in Parameters
###########################################

# Usage
usage() { echo "
Usage: $0 -a <docs1> -b <docs2> -t <setting> -k <no_topics> -s <start_init> -e <end_init> -m <MMLDA_dir> -o <out_dir> 
[-q <queue>]
    - docs1         Text file with each line summarizing the document of first 
                    modality; e.g., brain atrophy doc
    - docs2         Text file with each line summarizing the document of second
                    modality; e.g., cognitive scores doc (generated by xxx)
    - setting       Setting file for MMLDA model; e.g., 
                    $CBIG_CODE_DIR/external_packages/mmlda-c-dist/setting-100iter.txt
    - no_topics     Number of topics / factors; e.g., 3
    - start_init    Start index of random initializations; e.g., 1
    - end_init      End index of random initializations; e.g., 20; then the MMLDA
                    model would run 1, 2, ..., 20 random initializations. And,
                    the index corresponds to the random seed, so it is easy to 
                    replicate results by specifying same random seed.
    - MMLDA_dir     Directory of binary executable file for MMLDA 
    - out_dir       Output directory; e.g., ~/outputs/MMLDA/
    - queue         (Optional) if you have a cluster, use it to specify the 
                    queue to which you want to qsub these jobs; if not provided,
                    jobs will run serially (potentially very slow!)
" 1>&2; exit 1; }

# Reading in parameters
while getopts ":a:b:t:k:s:e:m:o:q:" opt; do
    case "${opt}" in
        a) docs1=${OPTARG};;
        b) docs2=${OPTARG};;
        t) setting=${OPTARG};;
        k) no_topics=${OPTARG};;
        s) start_init=${OPTARG};;
        e) end_init=${OPTARG};;
        m) MMLDA_dir=${OPTARG};;
        o) out_dir=${OPTARG};;
        q) queue=${OPTARG};;
        *) usage;;
    esac
done
shift $((OPTIND-1))
if [ -z "${docs1}" ] || [ -z "${docs2}" ] || [ -z "${setting}" ] || \
     [ -z "${no_topics}" ] || [ -z "${start_init}" ] || [ -z "${end_init}" ] || \
     [ -z "${MMLDA_dir}" ] || [ -z "${out_dir}" ]; then
    echo Missing Parameters!
    usage
fi

###########################################
# Main
###########################################

echo '---MMLDA estimation.'

mkdir -p ${out_dir}/k${no_topics}

progress_file=${out_dir}/k${no_topics}/progress.txt
> ${progress_file}
for (( r=${start_init}; r<=${end_init}; r++ )); do
    run_dir=${out_dir}/k${no_topics}/r${r}
    mkdir -p ${run_dir}
    log_file=${run_dir}/mmlda.log
    > ${log_file}

    # initialize alpha to be 1/no_topics
    alpha=$(echo 1/${no_topics} | bc -l)

    if [ -z "${queue}" ]; then
        # converting relative paths to absolute for qsub
        setting=$(readlink -f ${setting})
        docs1=$(readlink -f ${docs1})
        docs2=$(readlink -f ${docs2})
        run_dir=$(readlink -f ${run_dir})

        date >> ${log_file}
        echo "Docs: ${docs1} ${docs2}" >> ${log_file}
        echo "Number of topics: ${no_topics}" >> ${log_file}
        echo "Settings:" >> ${log_file}
        cat ${setting} >> ${log_file}

        ${MMLDA_dir}/MMLDA est ${alpha} ${no_topics} ${setting} ${docs1} ${docs2} random ${run_dir} ${r} >> ${log_file}
        echo "${r}" >> ${progress_file}
    else
        ERR_FILE_PATH=${run_dir}/mmlda.err
        OUT_FILE_PATH=${run_dir}/mmlda.out
    
        # converting relative paths to absolute for qsub
        setting=$(readlink -f ${setting})
        docs1=$(readlink -f ${docs1})
        docs2=$(readlink -f ${docs2})
        run_dir=$(readlink -f ${run_dir})

        date >> ${log_file}
        echo "Docs: ${docs1} ${docs2}" >> ${log_file}
        echo "Number of topics: ${no_topics}" >> ${log_file}
        echo "Settings:" >> ${log_file}
        cat ${setting} >> ${log_file}

        cmd="${MMLDA_dir}/MMLDA est ${alpha} ${no_topics} ${setting} ${docs1} ${docs2} random ${run_dir} ${r}"
        cmd="$cmd | tee -a ${log_file}"
        script_file=${run_dir}/job_submitted.sh
        echo "#!/bin/bash" > ${script_file}
        echo $cmd >> ${script_file}
        chmod 750 ${script_file}

        $CBIG_CODE_DIR/setup/CBIG_pbsubmit -cmd "$script_file" -walltime 2:00:00 -mem 3G -name "MMLDA_est" \
-joberr ${ERR_FILE_PATH} -jobout ${OUT_FILE_PATH}

        echo "${r}" >> ${progress_file}

    fi
done

# total_num_job=$((${end_init}-${start_init}+1))

# ./CBIG_MMLDA_wait_until_finished.sh ${progress_file} ${total_num_job}

# echo "---MMLDA estimation. -- Finished."
