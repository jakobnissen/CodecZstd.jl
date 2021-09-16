# Low-level Interfaces
# ====================

function iserror(code::Csize_t)
    return Lib.ZSTD_isError(code) != 0
end

function zstderror(stream, code::Csize_t)
    ptr = Lib.ZSTD_getErrorName(code)
    error("zstd error: ", unsafe_string(ptr))
end

function max_clevel()
    return Lib.ZSTD_maxCLevel()
end

const MAX_CLEVEL = max_clevel()

# ZSTD_outBuffer
#=
mutable struct InBuffer
    src::Ptr{Cvoid}
    size::Csize_t
    pos::Csize_t

    function InBuffer()
        return new(C_NULL, 0, 0)
    end
end
=#

# ZSTD_inBuffer
#=
mutable struct OutBuffer
    dst::Ptr{Cvoid}
    size::Csize_t
    pos::Csize_t

    function OutBuffer()
        return new(C_NULL, 0, 0)
    end
end
=#
const InBuffer = Lib.ZSTD_inBuffer
InBuffer() = InBuffer(C_NULL, 0, 0)
const OutBuffer = Lib.ZSTD_outBuffer
OutBuffer() = OutBuffer(C_NULL, 0, 0)

# ZSTD_CStream
mutable struct CStream
    ptr::Ptr{Cvoid}
    ibuffer::InBuffer
    obuffer::OutBuffer

    function CStream()
        ptr = Lib.ZSTD_createCStream()
        if ptr == C_NULL
            throw(OutOfMemoryError())
        end
        return new(ptr, InBuffer(), OutBuffer())
    end
end

function initialize!(cstream::CStream, level::Integer)
    return Lib.ZSTD_initCStream(cstream.ptr, level)
end

function reset!(cstream::CStream, srcsize::Integer)
    # ZSTD_resetCStream is deprecated
    # https://github.com/facebook/zstd/blob/9d2a45a705e22ad4817b41442949cd0f78597154/lib/zstd.h#L2253-L2272
    res = Lib.ZSTD_CCtx_reset(cstream.ptr, Lib.ZSTD_reset_session_only)
    if iserror(res)
        return res
    end
    if srcsize == 0
        # From zstd.h:
        # Note: ZSTD_resetCStream() interprets pledgedSrcSize == 0 as ZSTD_CONTENTSIZE_UNKNOWN, but
        # ZSTD_CCtx_setPledgedSrcSize() does not do the same, so ZSTD_CONTENTSIZE_UNKNOWN must be
        # explicitly specified.
        srcsize = ZSTD_CONTENTSIZE_UNKNOWN
    end
    return Lib.ZSTD_CCtx_setPledgedSrcSize(cstream.ptr, srcsize)
    #return ccall((:ZSTD_resetCStream, libzstd), Csize_t, (Ptr{Cvoid}, Culonglong), cstream.ptr, srcsize)

end

function compress!(cstream::CStream)
    return Lib.ZSTD_compressStream(cstream.ptr, pointer_from_objref(cstream.obuffer), pointer_from_objref(cstream.ibuffer))
end

function finish!(cstream::CStream)
    return Lib.ZSTD_endStream(cstream.ptr, pointer_from_objref(cstream.obuffer))
end

function free!(cstream::CStream)
    return Lib.ZSTD_freeCStream(cstream.ptr)
end

# ZSTD_DStream
mutable struct DStream
    ptr::Ptr{Cvoid}
    ibuffer::InBuffer
    obuffer::OutBuffer

    function DStream()
        ptr = Lib.ZSTD_createDStream()
        if ptr == C_NULL
            throw(OutOfMemoryError())
        end
        return new(ptr, InBuffer(), OutBuffer())
    end
end

function initialize!(dstream::DStream)
    return Lib.ZSTD_initDStream(dstream.ptr)
end

function reset!(dstream::DStream)
    # Lib.ZSTD_resetDStream is deprecated
    # https://github.com/facebook/zstd/blob/9d2a45a705e22ad4817b41442949cd0f78597154/lib/zstd.h#L2332-L2339
    return Lib.ZSTD_DCtx_reset(dstream.ptr, Lib.ZSTD_reset_session_only)
    #return ccall((:ZSTD_resetDStream, libzstd), Csize_t, (Ptr{Cvoid},), dstream.ptr)
end

function decompress!(dstream::DStream)
    return Lib.ZSTD_decompressStream(dstream.ptr, pointer_from_objref(dstream.obuffer), pointer_from_objref(dstream.ibuffer))
end

function free!(dstream::DStream)
    return Lib.ZSTD_freeDStream(dstream.ptr)
end


# Misc. functions
# ---------------

const ZSTD_CONTENTSIZE_UNKNOWN = Culonglong(0) - 1
const ZSTD_CONTENTSIZE_ERROR   = Culonglong(0) - 2

function find_decompressed_size(src::Ptr, size::Integer)
    return Lib.ZSTD_findDecompressedSize(src, size)
    #return ccall((:ZSTD_findDecompressedSize, libzstd), Culonglong, (Ptr{Cvoid}, Csize_t), src, size)
end
