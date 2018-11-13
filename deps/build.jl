using PyCall
using Conda

const cur_version = "1.10.0"
const cur_py_version = "1.10.0"


############################
# Error message for Windows
############################

if Sys.iswindows()
    error("TensorFlow.jl does not support Windows. Please see https://github.com/malmaud/TensorFlow.jl/issues/204")
end

############################
# Determine if using GPU
############################

use_gpu = "TF_USE_GPU" ∈ keys(ENV) && ENV["TF_USE_GPU"] == "1"

if Sys.isapple() && use_gpu
    @warn("No support for TF_USE_GPU on OS X - to enable the GPU, build TensorFlow from source. Falling back to CPU")
    use_gpu=false
end

if use_gpu
    @info("Building TensorFlow.jl for use on the GPU")
else
    @info("Building TensorFlow.jl for CPU use only. To enable the GPU, set the TF_USE_GPU environment variable to 1 and rebuild TensorFlow.jl")
end

############################
# Install libtensorflow
############################

base = dirname(@__FILE__)
download_dir = joinpath(base, "downloads")
dl_lib_dir = joinpath(download_dir, "lib")
usr_lib_dir = joinpath(base, "usr", "lib")

mkpath(dl_lib_dir)

function download_and_unpack(url)
    tensorflow_zip_path = joinpath(base, "downloads", "tensorflow.tar.gz")
    download(url, tensorflow_zip_path)
    run(`tar -xzf $tensorflow_zip_path -C downloads`)
end

@static if Sys.isapple()
    if use_gpu
        url = "https://storage.googleapis.com/tensorflow/libtensorflow/libtensorflow-gpu-darwin-x86_64-$cur_version.tar.gz"
    else
        url = "https://storage.googleapis.com/tensorflow/libtensorflow/libtensorflow-cpu-darwin-x86_64-$cur_version.tar.gz"
    end
    download_and_unpack(url)
    mkpath(joinpath(base, "usr", "lib"))
    mv(joinpath(dl_lib_dir, "libtensorflow.so"), joinpath(usr_lib_dir, "libtensorflow.dylib"), force=true)
    mv(joinpath(dl_lib_dir, "libtensorflow_framework.so"), joinpath(usr_lib_dir, "libtensorflow_framework.so"), force=true)
end

@static if Sys.islinux()
    if use_gpu
        url = "https://github.com/JuliaPackaging/Yggdrasil/releases/download/XRTServer-v2018.11.12/XRTServer.v2018.11.12.x86_64-linux-gnu.tar.gz"
    else
        url = "https://github.com/JuliaPackaging/Yggdrasil/releases/download/XRTServer_lite-v2018.11.1/XRTServer_lite.v2018.11.1.x86_64-linux-gnu.tar.gz"
    end
    download_and_unpack(url)

    rm(usr_lib_dir; force=true, recursive=true)
    mkpath(dirname(usr_lib_dir))
    symlink(dl_lib_dir, usr_lib_dir)

    # If the user actually wants to use the GPU, we need to move `libcuda.so.1` to a different name
    # so that libtensorflow links against the system-wide libcuda
    libcuda = joinpath(base, "downloads", "lib64", "libcuda.so.1")
    if use_gpu && isfile(libcuda)
        mv(libcuda, "$(libcuda).use_gpu")
    elseif !use_gpu && isfile("$(libcuda).use_gpu")
        mv("$(libcuda).use_gpu", libcuda)
    end
end
