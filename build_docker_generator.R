library(trailrun)
library(googleCloudRunner)
setup = cr_gce_setup()

get_image_basename = function(x) {
  sub("Dockerfile_", "", basename(x), ignore.case = TRUE)
}

get_image_yaml_filename = function(x) {
  bn = get_image_basename(x)
  yaml_filename = paste0("cloudbuild/", bn, ".yaml")  
}

get_image_name = function(x) {
  repo = "us-docker.pkg.dev/streamline-resources/streamline-private-repo/"
  bn = get_image_basename(x)
  image = paste0(repo, bn)
}

write_docker_cloudbuild_yaml = function(dockerfile) {
  yaml_filename = get_image_yaml_filename(dockerfile)
  image = get_image_name(dockerfile)
  
  steps = c(
    googleCloudRunner::cr_buildstep_gitsetup(secret = "ssh-deploy-key"),
    cr_buildstep_git_clone(
      "git@github.com:StreamlineDataScience/streamline_startup_scripts.git",
      default_directory = "/workspace"
    ),
    cr_buildstep_docker(
      image = image,
      dockerfile = dockerfile, 
      build_args = "--network=cloudbuild")
  )
  yaml = cr_build_yaml(steps, timeout = 3600L)
  cr_build_write(yaml, file = yaml_filename, footer = FALSE)
  return(yaml_filename)
}

cr_docker_trigger = function(dockerfile) {
  yaml_filename = get_image_yaml_filename(dockerfile)
  trailrun::cr_github_trigger(
    name = get_image_basename(dockerfile),
    includedFiles = c(
      dockerfile, 
      yaml_filename
    ),
    yaml_filename = yaml_filename
  )
}


dockerfile = "dockerfiles/Dockerfile_streambase"
write_docker_cloudbuild_yaml(dockerfile)
cr_docker_trigger(dockerfile)


