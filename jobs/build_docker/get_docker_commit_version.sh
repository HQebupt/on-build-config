#!/bin/bash 
set -e

rackhd_docker_images=`ls ${DOCKER_PATH}`
build_record=`ls ${DOCKER_RECORD_PATH}`
docker_repo_commit_file="${DOCKER_REPO_HASHCODE_FILE}"
commit_string_file=commitstring.txt

# load docker images
docker load -i $rackhd_docker_images
image_list=`head -n 1 $build_record`

#get docker commit hashcode, store in file:docker_repo_hashcode.txt
rm -rf $docker_repo_commit_file
for repo_tag in $image_list; do
    repo_tmp="${repo_tag%:*}" 
    repo="${repo_tmp##'rackhd/'}"
    echo "[Debug] rep_tag:${repo_tag}, repo:${repo}"
    if [ "$repo" == "files" ]; then
    	continue
    elif [ "$repo" == "ucs-service" ]; then
    	commitstring="$(docker run $repo_tag cat /usr/src/app/$commit_string_file)"
    else
        commitstring="$(docker run $repo_tag cat /RackHD/$repo/$commit_string_file)"
    	# commitstring.txt: cd49e2a.2017-06-11 17:27:19 -0400.Merge pull request #665 from keedya/master
    fi
    hashcode="${commitstring:0:7}"
    echo "$repo:$hashcode" >> $docker_repo_commit_file
done

