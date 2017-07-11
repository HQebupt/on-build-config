#!/bin/bash 
set -e

build_record=`ls ${DOCKER_RECORD_PATH}`
docker_repo_commit_file="${DOCKER_REPO_HASHCODE_FILE}"
commit_string_file=commitstring.txt

# load docker images
image_list=`head -n 1 $build_record`

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

#get docker commit hashcode, store in file:docker_repo_hashcode.txt
rm -rf $docker_repo_commit_file
for repo_tag in $image_list; do
    repo_tmp="${repo_tag%:*}" 
    repo="${repo_tmp##'rackhd/'}"
    echo "[Debug] rep_tag:${repo_tag}, repo:${repo}"
    case "$repo" in
    "on-core" | "on-tasks")
        ;;
    "files")
        container_id="$(docker ps -q --filter ancestor=${repo_tag} --format="{{.ID}}")"
        echo "[DEBUG] repo_tag:${repo_tag}, running container_id:${container_id}"
        commitstring="$(docker exec  ${container_id}  cat /RackHD/downloads/common/$commit_string_file)"
        hashcode="${commitstring:0:7}"
        echo "[DEBUG]repo:${repo}, commitstring:${commitstring}, hashcode:${hashcode}"
        echo "on-imagebuilder:$hashcode" >> $docker_repo_commit_file
        ;;

    "on-http")
        container_id="$(docker ps -q --filter ancestor=${repo_tag} --format="{{.ID}}")"
        echo "[DEBUG] repo_tag:${repo_tag}, running container_id:${container_id}"
        commitstring="$(docker exec  ${container_id}  cat /RackHD/$repo/$commit_string_file)"
        hashcode="${commitstring:0:7}"
        echo "[DEBUG]repo:${repo}, commitstring:${commitstring}, hashcode:${hashcode}"
        echo "$repo:$hashcode" >> $docker_repo_commit_file

        commitstring_on_core="$(docker exec $container_id cat /RackHD/$repo/node_modules/on-core/commitstring.txt)"
        hashcode="${commitstring_on_core:0:7}"
        echo "on-core:$hashcode" >> $docker_repo_commit_file

        commitstring_on_tasks="$(docker exec $container_id cat /RackHD/$repo/node_modules/on-tasks/commitstring.txt)"
        hashcode="${commitstring_on_tasks:0:7}"
        echo "on-tasks:$hashcode" >> $docker_repo_commit_file
        ;;

    "on-wss" | "on-statsd" | "ucs-service")
        if [ "$repo" == "ucs-service" ]; then
            commitstring="$(docker run  ${repo_tag} cat /usr/src/app/$commit_string_file)"
        else
            commitstring="$(docker run  ${repo_tag}  cat /RackHD/$repo/$commit_string_file)"
        fi
        hashcode="${commitstring:0:7}"
        echo "[DEBUG]repo:${repo}, commitstring:${commitstring}, hashcode:${hashcode}"
        echo "$repo:$hashcode" >> $docker_repo_commit_file

        # clean up env
        container_id="$(docker ps -a -q --filter ancestor=${repo_tag} --format="{{.ID}}")"
        for container in ${container_id}; do
            echo "[DEBUG] docker rm container:${container}, belong repo:$repo"
            docker rm $container
        done
        ;;

    *)
        container_id="$(docker ps -q --filter ancestor=${repo_tag} --format="{{.ID}}")"
        echo "[DEBUG] repo_tag:${repo_tag}, running container_id:${container_id}"
        commitstring="$(docker exec  ${container_id}  cat /RackHD/$repo/$commit_string_file)"
        hashcode="${commitstring:0:7}"
        echo "[DEBUG]repo:${repo}, commitstring:${commitstring}, hashcode:${hashcode}"
        echo "$repo:$hashcode" >> $docker_repo_commit_file
        ;;
    esac
done



