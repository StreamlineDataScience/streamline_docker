library(trailrun)
library(dplyr)
library(containerit)
library(googleCloudRunner)
source("docker_functions.R")

trailrun::cr_gce_setup()

r_ver = trailrun::rocker_versions() %>% 
  filter(base_image %in% "r-ver") %>% 
  mutate(full_image = paste0("rocker/", image))

from = containerit::clean_session()

docker_instructions = c(
  containerit::Env("_R_CHECK_CRAN_INCOMING_", "false"), 
  containerit::Copy("package_scripts", "/package_scripts", 
                    addTrailingSlashes = FALSE),
  containerit::Run_shell("chmod +x /package_scripts/*"),
  containerit::Run("/rocker_scripts/install_python.sh"),
  # related to https://github.com/rstudio/reticulate/issues/1190
  containerit::Run(
  "python -m pip install numpy --force-reinstall --no-binary numpy")
  
)

pre_steps = NULL

version = "4.1.2"
# for (index in seq(nrow(r_ver))) {
from_image_base = "renv-base"
from_image = paste0(from_image_base, "-", version)

from_image = trailrun::streamline_private_image(from_image)

image_basename = "renv-package"
image_name = paste0(image_basename, "-", version)
dockerfile_name = paste0("dockerfiles/Dockerfile_", image_name)

result = containerit::dockerfile(
  maintainer = "Streamline_Data_Science",
  from = from,
  image = from_image,
  offline = TRUE,
  container_workdir = "./",
  instructions = docker_instructions,
  platform = "linux-x86_64-ubuntu-gcc"
)
containerit::write(result, file = dockerfile_name)

image_url = trailrun::streamline_private_image(image_name)


build2 = function(image_name, ...) {
  build_args = c("--cache-from", paste0(image_name, ":latest"))
  googleCloudRunner::cr_deploy_docker(
    ...,
    image_name = image_name,
    timeout = 3600L,
    images = image_name,
    build_args = build_args,
    kaniko_cache = FALSE,
    # options = list(machineType = "N1_HIGHCPU_8"),
    volumes = googleCloudRunner::git_volume(),
  )
}

result = build2(
  local = "~/streamline_docker",
  image_name = image_url,
  dockerfile = dockerfile_name,
  pre_steps = pre_steps,
  launch_browser = FALSE
)
