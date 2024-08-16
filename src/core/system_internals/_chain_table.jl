const _chain_table_schema = Tables.Schema(
    (:idx, :name),
    (Int, String)
)
const _chain_table_cols = _chain_table_schema.names
const _chain_table_cols_set = Set(_chain_table_cols)
const _chain_table_cols_priv = Set([:properties, :flags, :molecule_idx])

@auto_hash_equals struct _ChainTable <: AbstractColumnTable
    # public columns
    idx::Vector{Int}
    name::Vector{String}

    # private columns
    properties::Vector{Properties}
    flags::Vector{Flags}
    molecule_idx::Vector{Int}

    # internals
    _idx_map::Dict{Int,Int}

    function _ChainTable()
        new(
            Int[],
            String[],
            Properties[],
            Flags[],
            Int[],
            Dict{Int,Int}()
        )
    end
end

@inline Tables.columnnames(::_ChainTable) = _chain_table_cols
@inline Tables.schema(::_ChainTable) = _chain_table_schema

@inline function Tables.getcolumn(ct::_ChainTable, nm::Symbol)
    @assert nm in _chain_table_cols_priv || nm in _chain_table_cols_set "type _ChainTable has no column $nm"
    getfield(ct, nm)
end

@inline Base.size(ct::_ChainTable) = (length(ct.idx), length(_chain_table_cols))

function Base.push!(
    ct::_ChainTable,
    idx::Int,
    molecule_idx::Int;
    name::String = "",
    properties::Properties = Properties(),
    flags::Flags = Flags()
)
    ct._idx_map[idx] = length(ct.idx) + 1
    push!(ct.idx, idx)
    push!(ct.name, name)
    push!(ct.properties, properties)
    push!(ct.flags, flags)
    push!(ct.molecule_idx, molecule_idx)
    ct
end

@inline function _rebuild_idx_map!(ct::_ChainTable)
    empty!(ct._idx_map)
    merge!(ct._idx_map, Dict(v => k for (k, v) in enumerate(ct.idx)))
    ct
end

function _delete!(ct::_ChainTable, rowno::Int)
    deleteat!(ct.idx, rowno)
    deleteat!(ct.name, rowno)
    deleteat!(ct.properties, rowno)
    deleteat!(ct.flags, rowno)
    deleteat!(ct.molecule_idx, rowno)
    nothing
end

function Base.delete!(ct::_ChainTable, idx::Int)
    _delete!(ct, ct._idx_map[idx])
    _rebuild_idx_map!(ct)
end

function Base.delete!(ct::_ChainTable, idx::Vector{Int})
    rownos = getindex.(Ref(ct._idx_map), idx)
    unique!(rownos)
    sort!(rownos; rev = true)
    for rowno in rownos
        _delete!(ct, rowno)
    end
    _rebuild_idx_map!(ct)
end

function Base.empty!(ct::_ChainTable)
    empty!(ct.idx)
    empty!(ct.name)
    empty!(ct.properties)
    empty!(ct.flags)
    empty!(ct.molecule_idx)
    empty!(ct._idx_map)
    ct
end

function _chain_table(itr)
    ct = _ChainTable()
    for c in itr
        push!(ct, c.idx, c.molecule_idx;
            name = c.name,
            properties = c.properties,
            flags = c.flags
       )
    end
    ct
end
@inline Tables.materializer(::Type{_ChainTable}) = itr -> _chain_table(itr)

@inline _rowno_by_idx(ct::_ChainTable, idx::Int) = getindex(getfield(ct, :_idx_map), idx)
@inline _row_by_idx(ct::_ChainTable, idx::Int) = ColumnTableRow(_rowno_by_idx(ct, idx), ct)
