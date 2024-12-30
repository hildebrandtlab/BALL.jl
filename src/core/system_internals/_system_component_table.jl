abstract type _AbstractSystemComponentTable <: AbstractColumnTable end

const _IdxMap = Dict{Int, Int}

@inline function _rowno_by_idx(at::_AbstractSystemComponentTable, idx::Int)
    getindex(getfield(at, :_idx_map), idx)
end

@inline function _row_by_idx(at::_AbstractSystemComponentTable, idx::Int)
    ColumnTableRow(_rowno_by_idx(at, idx), at)
end

function _rebuild_idx_map!(at::_AbstractSystemComponentTable)
    empty!(at._idx_map)
    for (k, v) in enumerate(at.idx)
        setindex!(at._idx_map, k, v)
    end
    at
end

@generated function _delete!(at::_AbstractSystemComponentTable, rowno::Int)
    args = [
        :(deleteat!(getfield(at, $(QuoteNode(nm))), rowno))
        for nm in fieldnames(at)
        if nm !== :_idx_map
    ]
    Expr(:block, args..., :(nothing))
end

function Base.delete!(at::_AbstractSystemComponentTable, idx::Int)
    _delete!(at, _rowno_by_idx(at, idx))
    _rebuild_idx_map!(at)
end

function Base.delete!(at::_AbstractSystemComponentTable, idx::Vector{Int})
    rownos = _rowno_by_idx.(Ref(at), idx)
    unique!(rownos)
    sort!(rownos; rev = true)
    for rowno in rownos
        _delete!(at, rowno)
    end
    _rebuild_idx_map!(at)
end

@generated function Base.empty!(at::_AbstractSystemComponentTable)
    args = [
        :(empty!(getfield(at, $(QuoteNode(nm)))))
        for nm in fieldnames(at)
    ]
    Expr(:block, args..., :(at))
end

@inline function _sort_table_getperm(at, idx)
    map(i -> at._idx_map[i], idx)
end

@inline function _sort_table_getidx(e)
    e.idx
end

@generated function Base.sort!(at::_AbstractSystemComponentTable; kwargs...)
    Expr(:block,
        :(perm = _sort_table_getperm(at, getproperty.(sort(collect(at); by=_sort_table_getidx, kwargs...), :idx))),
        [
            :(permute!(getfield(at, $(QuoteNode(nm))), perm))
            for nm in fieldnames(at)
            if nm !== :_idx_map
        ]...,
        :(_rebuild_idx_map!(at)),
        :(at)
    )
end

@inline Base.size(at::_AbstractSystemComponentTable) = (length(at.idx), length(Tables.columnnames(at)))

@inline function Tables.getcolumn(at::_AbstractSystemComponentTable, nm::Symbol)
    @assert _hascolumn(at, nm) "type $(typeof(at)) has no column $nm"
    getfield(at, nm)
end
