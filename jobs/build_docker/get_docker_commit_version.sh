#!/bin/bash 
set -e
set -x

build_record=`ls ${DOCKER_RECORD_PATH}`
image_list=`head -n 1 $build_record`
docker_repo_commit_file="${DOCKER_REPO_HASHCODE_FILE}"
commit_string_file=commitstring.txt

# global var
on_core_hash=
on_tasks_hash=
hashcode=

# basic check, clean env
prepare_check_test(){
    running_container="$(docker ps -q | wc -l)"
    echo "[DEBUG] all running_container count:${running_container}"

    time=1
    MAX_TRY=10
    while [ ${running_container} -lt 9 ] && [ ${time} -le ${MAX_TRY} ]; do
        sleep 10
        running_container="$(docker ps -q | wc -l)"
        echo "[DEBUG] [${time}*10s] all running_container count:${running_container}"
        time=`expr ${time} + 1`
    done

    if [ ${running_container} -lt 9 ]; then
        echo "[ERROR] not all containers is running, only ${running_container}, need 9."
        exit 1
    fi
    rm -rf ${docker_repo_commit_file}
}
    
# clean up docker env: clean_docker_env ${repo_tag}
clean_docker_env(){
    container_id="$(docker ps -a -q --filter ancestor=$1 --format="{{.ID}}")"
    for container in ${container_id}; do
        echo "[DEBUG] docker rm container:${container}"
        docker rm ${container}
    done    
}

# is_core_correct ${hashcode}
is_core_correct(){
    if [ -z "${on_core_hash}" ]; then 
        echo "on-core hashcode is empty. set value." 
        on_core_hash="$1"
    else
        echo "on-core hashcode is not empty. compare value."  
        if [ "${on_core_hash}" != "$1" ]; then
            echo "[ERROR] on-core hashcode is not coincident. ${on_core_hash}:$1"
            exit 1
        fi
    fi
}

# is_tasks_correct ${hashcode}
is_tasks_correct(){
    if [ -z "${on_tasks_hash}" ]; then 
        echo "on-tasks hashcode is empty. set value." 
        on_tasks_hash="$1"
    else
        echo "on-tasks hashcode is not empty. compare value."  
        if [ "${on_tasks_hash}" != "$1" ]; then
            echo "[ERROR] on-tasks hashcode is not coincident. ${on_tasks_hash}:$1"
            exit 1
        fi
    fi
}

# get hashcode: get_repo_hashcode ${commitstring} ${repo}
get_repo_hashcode(){
    commitstring=$1
    repo=$2
    hashcode="${commitstring:0:7}"
    echo "[DEBUG]repo:${repo}, commitstring:${commitstring}, hashcode:${hashcode}"
    echo "${repo}:${hashcode}" >> ${docker_repo_commit_file}
}

# check on core hashcode: check_on_core_hashcode ${commitstring} ${repo} ${repo_tag} ${cmd}
check_on_core_hashcode(){
    commitstring=$1
    repo=$2
    repo_tag=$3
    cmd=$4
    on_core_commitstring="$(docker ${command}  ${repo_tag}  cat /RackHD/${repo}/node_modules/on-core/${commit_string_file})"
    on_core_hashcode="${on_core_commitstring:0:7}"
    is_core_correct ${on_core_hashcode}
}

# check on tasks hashcode: check_on_tasks_hashcode ${commitstring} ${repo} ${repo_tag} ${cmd}
check_on_tasks_hashcode(){
    commitstring=$1
    repo=$2
    repo_tag=$3
    cmd=$4
    on_tasks_commitstring="$(docker ${command}  ${repo_tag}  cat /RackHD/${repo}/node_modules/on-tasks/${commit_string_file})"
    on_tasks_hashcode="${on_tasks_commitstring:0:7}"
    is_tasks_correct ${on_tasks_hashcode}
}

# get docker commit hashcode, store in file:docker_repo_hashcode.txt
prepare_check_test
for repo_tag in $image_list; do
    repo_tmp="${repo_tag%:*}" 
    repo="${repo_tmp##'rackhd/'}"
    echo "[Debug] rep_tag:${repo_tag}, repo:${repo}"
    case "${repo}" in
    "ucs-service")
        ;;

    "files")
        container_id="$(docker ps -q --filter ancestor=${repo_tag} --format="{{.ID}}")"
        echo "[DEBUG] repo_tag:${repo_tag}, running container_id:${container_id}"
        commitstring="$(docker exec  ${container_id}  cat /RackHD/downloads/common/${commit_string_file})"
        get_repo_hashcode ${commitstring} ${repo}
        ;;

    "on-wss" | "on-statsd")
        commitstring="$(docker run  ${repo_tag}  cat /RackHD/${repo}/${commit_string_file})"
        get_repo_hashcode ${commitstring} ${repo}
        
        check_on_core_hashcode ${commitstring} ${repo} ${repo_tag} "run"
        clean_docker_env ${repo_tag}
        ;;

    "on-core")
        commitstring="$(docker run  ${repo_tag}  cat /RackHD/${repo}/${commit_string_file})"
        get_repo_hashcode ${commitstring} ${repo}
        is_core_correct ${hashcode}

        clean_docker_env ${repo_tag}
        ;;

    "on-tasks")
        commitstring="$(docker run  ${repo_tag}  cat /RackHD/${repo}/${commit_string_file})"
        get_repo_hashcode ${commitstring} ${repo}
        is_tasks_correct ${hashcode}

        check_on_core_hashcode ${commitstring} ${repo} ${repo_tag} "run"
        clean_docker_env ${repo_tag}
        ;;

    "on-http" | "on-taskgraph")
        container_id="$(docker ps -q --filter ancestor=${repo_tag} --format="{{.ID}}")"
        echo "[DEBUG] repo_tag:${repo_tag}, running container_id:${container_id}"
        commitstring="$(docker exec  ${container_id}  cat /RackHD/${repo}/${commit_string_file})"
        get_repo_hashcode ${commitstring} ${repo}

        check_on_core_hashcode ${commitstring} ${repo} ${repo_tag} "exec"
        check_on_tasks_hashcode ${commitstring} ${repo} ${repo_tag} "exec"
        ;;

    "on-syslog" | "on-dhcp-proxy" | "on-tftp")
        container_id="$(docker ps -q --filter ancestor=${repo_tag} --format="{{.ID}}")"
        echo "[DEBUG] repo_tag:${repo_tag}, running container_id:${container_id}"
        commitstring="$(docker exec  ${container_id}  cat /RackHD/${repo}/${commit_string_file})"
        get_repo_hashcode ${commitstring} ${repo}

        check_on_core_hashcode ${commitstring} ${repo} ${repo_tag} "exec"
        ;;
    esac
done
