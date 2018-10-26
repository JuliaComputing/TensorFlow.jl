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



#############################
# Install Python TensorFlow
#############################

if PyCall.conda
    Conda.add_channel("conda-forge")
    Conda.add("tensorflow=" * cur_py_version)
else
    try
        pyimport("tensorflow")
        # See if it works already
    catch ee
        typeof(ee) <: PyCall.PyError || rethrow(ee)
        error("""
Python TensorFlow not installed
Please either:
 - Rebuild PyCall to use Conda, by running in the julia REPL:
    - `ENV["PYTHON"]=""; Pkg.build("PyCall"); Pkg.build("TensorFlow")`
 - Or install the python binding yourself, eg by running pip
    - `pip install tensorflow`
    - then rebuilding TensorFlow.jl via `Pkg.build("TensorFlow")` in the julia REPL
    - make sure you run the right pip, for the instance of python that PyCall is looking at.
""")
    end
end


############################
# Install libtensorflow
############################

base = dirname(@__FILE__)
download_dir = joinpath(base, "downloads")
lib_dir = joinpath(download_dir, "lib")
bin_dir = joinpath(base, "usr/bin")

mkpath(download_dir)
mkpath(lib_dir)
mkpath(bin_dir)


function download_and_unpack(url)
    tensorflow_zip_path = joinpath(base, "downloads/tensorflow.tar.gz")
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
    mv("$lib_dir/libtensorflow.so", "usr/bin/libtensorflow.dylib", force=true)
    mv("$lib_dir/libtensorflow_framework.so", "usr/bin/libtensorflow_framework.so", force=true)
end

@static if Sys.islinux()
    url = "https://github.com/JuliaPackaging/Yggdrasil/releases/download/XRTServer-v2018.10.25/XRTServer.v2018.10.25.x86_64-linux-gnu.tar.gz"
    download_and_unpack(url)
    rm("usr/bin/libtensorflow.so"; force=true)
    symlink("../../downloads/lib/libtensorflow.so", "usr/bin/libtensorflow.so")
    rm("usr/bin/libtensorflow_framework.so"; force=true)
    symlink("../../downloads/lib/libtensorflow_framework.so", "usr/bin/libtensorflow_framework.so")
    rm("downloads/bin/cuda_sdk_lib"; force=true)
    symlink("../nvvm/libdevice", "downloads/bin/cuda_sdk_lib")

    # If the user actually wants to use the GPU, we need to move `libcuda.so.1` to a different name
    # so that libtensorflow links against the system-wide libcuda
    if use_gpu && isfile("downloads/lib64/libcuda.so.1")
        mv("downloads/lib64/libcuda.so.1", "downloads/lib64/libcuda.so.1.use_gpu")
    elseif !use_gpu && isfile("downloads/lib64/libcuda.so.1.use_gpu")
        mv("downloads/lib64/libcuda.so.1.use_gpu", "downloads/lib64/libcuda.so.1")
    end
end
