#!/usr/bin/env julia

# CUDAdrv.jl version

using CUDAdrv
using InteractiveUtils

const len = 1000
const ITERATIONS = 5000

# TODO: api-trace shows some attribute fetches, where do they come from?

const dev = CuDevice(0)
const ctx = CuContext(dev)

const mod = CuModuleFile("cuda.ptx")
const fun = CuFunction(mod, "kernel_dummy")

function benchmark(gpu_buf)
    cudacall(fun, (Ptr{Float32},), gpu_buf; threads=1)
    return
end


function main()
    cpu_time = Vector{Float64}(ITERATIONS)
    gpu_time = Vector{Float64}(ITERATIONS)

    gpu_buf = Mem.alloc(len*sizeof(Float32))
    @code_warntype benchmark(gpu_buf)
    for i in 1:ITERATIONS
        i == ITERATIONS-4 && CUDAdrv.Profile.start()

        gpu_tic, gpu_toc = CuEvent(), CuEvent()

        cpu_tic = time_ns()
        record(gpu_tic)
        benchmark(gpu_buf)
        record(gpu_toc)
        synchronize(gpu_toc)
        cpu_toc = time_ns()

        cpu_time[i] = (cpu_toc-cpu_tic)/1000
        gpu_time[i] = CUDAdrv.elapsed(gpu_tic, gpu_toc)*1000000
    end
    CUDAdrv.Profile.stop()
    Mem.free(gpu_buf)

    @printf("CPU time: %.2fus\n", median(cpu_time))
    @printf("GPU time: %.2fus\n", median(gpu_time))

    destroy!(ctx)
end

main()
