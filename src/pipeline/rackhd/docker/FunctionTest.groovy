package pipeline.rackhd.docker

def runTest(String stack_type, String test_name, ArrayList<String> used_resources, Map manifest_dict, Map docker_build_ret_dict, Map rackhd_cred_dict){
    def share_method = new pipeline.common.ShareMethod()
    String test_target = "docker"
    def fit_configure = new pipeline.fit.FitConfigure(stack_type, test_target, test_name)
    def fit_init_configure = new pipeline.fit.FitConfigure(stack_type, test_target, "INIT")

    fit_configure.configure()
    fit_init_configure.configure()
    String node_name = ""
    String label_name = fit_configure.getLabel()
    try{
        lock(label:label_name,quantity:1){
            node_name = share_method.occupyAvailableLockedResource(label_name, used_resources)
            echo "[DEBUG]node_name:${node_name}"
            node(node_name){
                deleteDir()
                def err = null
                def manifest = new pipeline.common.Manifest()
                def fit = new pipeline.fit.FIT()
                def virtual_node = new pipeline.nodes.VirtualNode()
                def rackhd_deployer = new pipeline.rackhd.docker.Deploy()
                String manifest_path = manifest.unstashManifest(manifest_dict, "$WORKSPACE")
                String library_dir = "$WORKSPACE/on-build-config"
                String rackhd_dir = "$WORKSPACE/RackHD"
                share_method.checkoutOnBuildConfig(library_dir)
                manifest.checkoutTargetRepo(manifest_path, "RackHD", rackhd_dir, library_dir)
                boolean ignore_failure = false
                String target_dir = test_target + "/" + test_name + "[$NODE_NAME]"
                String log_dir =" $WORKSPACE" + "/" + target_dir
                echo "rackhd_dir:${rackhd_dir}"
                echo "target_dir:${target_dir}"

                try{
                    // clean up rackhd and virtual nodes
                    rackhd_deployer.cleanUp(library_dir, rackhd_dir, ignore_failure)
                    echo "[DEBUG]rackhd_deployer cleanUp done."
                    virtual_node.cleanUp(library_dir, ignore_failure)
                    echo "[DEBUG]virtual_node cleanUp done."
                    virtual_node.stopFetchLogs(library_dir, target_dir)
                    echo "[DEBUG]virutal_node stopFetch done."

                    // deploy rackhd and virtual nodes
                    //String docker_build_unstash_name = docker_build_ret_dict["DOCKER_STASH_NAME"]
                    //unstash docker_build_unstash_name

                    sh """#!/bin/bash
                    echo "download docker images......"
                     wget -q http://10.240.19.21/job/SprintRelease/47/artifact/rackhd_docker_images.tar -O rackhd_docker_images.tar
                     wget -q http://10.240.19.21/job/SprintRelease/47/artifact/build_record -O build_record
                    """
                    String docker_tar_file   = "$WORKSPACE" + "/" + docker_build_ret_dict["DOCKER_STASH_PATH"]
                    rackhd_deployer.deploy(library_dir, log_dir, rackhd_dir, docker_tar_file)
                    echo "[DEBUG]rackhd_deployer.deploy done."
                    echo "Sleep1...."
                    sleep(60)
                    virtual_node.deploy(library_dir)
                    echo "[DEBUG]virtual_node deploy done."
                    echo "Sleep2...."
                    sleep(100)
                    virtual_node.startFetchLogs(library_dir, target_dir)
                    echo "[DEBUG]virtual_node startFetchLogs done."
                    echo "Sleep3...."
                    sleep(100)
                    // run FIT test
                    fit.configControlInterfaceIp(rackhd_dir)
                    echo "[DEBUG]fit configControlInterfaceIp done."
                    fit.configRackHDCredential(rackhd_dir, rackhd_cred_dict)
                    echo "[DEBUG]fit configRackHDCredential done"
                    fit.run(rackhd_dir, fit_init_configure)
                    echo "[DEBUG]fit run(rackhd_dir, fit_init_configure) done."
                    fit.run(rackhd_dir, fit_configure)
                    echo "[DEBUG]fit run(rackhd_dir, fit_configure) done."
               // } catch(run_error){
               //     err = error
               //     error("[ERROR] Failed to run test $test_name against $test_target with error: $run_error")
                } finally{
                    // archive rackhd logs
                    echo "[DEBUG]archive rackhd logs start."
                    rackhd_deployer.archiveLogsToTarget(library_dir, target_dir)
                    echo "[DEBUG]archive rackhd logs done."
                    fit.archiveLogsToTarget(target_dir, fit_configure)
                    echo "[DEBUG]fit archiveLogsToTarget done."
                    virtual_node.stopFetchLogs(library_dir, target_dir)
                    echo "[DEBUG]virtual_node stopFetchLogs done."
                    virtual_node.archiveLogsToTarget(target_dir)
                    echo "[DEBUG]virtual_node archiveLogsToTarget done."

                    // clean up rackhd and virtual nodes
                    ignore_failure = true
                    rackhd_deployer.cleanUp(library_dir, rackhd_dir, ignore_failure)
                    echo "[DEBUG]rackhd_deployer cleanUp done."
                    virtual_node.cleanUp(library_dir, ignore_failure)
                    echo "[DEBUG]virtual_node cleanUp done."
                    if(err){
                       throw err
                    }
                }
            }
         }
    } finally{
         used_resources.remove(node_name)
         echo "[DEBUG]used_resources remove done."
    }
}

return this


