export
    AbstractRMSDMinimizer,
    RMSDMinimizerCoutsias,
    RMSDMinimizerKabsch,
    RigidTransform,
    compute_rmsd,
    compute_rmsd_minimizer,
    map_rigid!,
    match_points,
    rigid_transform!,
    translate!

"""
    $(TYPEDEF)

Abstract base type for RMSD minimizers.
"""
abstract type AbstractRMSDMinimizer end

"""
    $(TYPEDEF)

Abstract base type for RMSD minimizers based on <https://doi.org/10.1107/S0567739476001873>.
"""
abstract type RMSDMinimizerKabsch <: AbstractRMSDMinimizer end

"""
    $(TYPEDEF)

Abstract base type for RMSD minimizers based on <https://doi.org/10.1002/jcc.20110>.
"""
abstract type RMSDMinimizerCoutsias <: AbstractRMSDMinimizer end

"""
    $(TYPEDEF)

Rigid transformation represented by a single rotation and translation.

# Constructors
```julia
RigidTransform(r::RotMatrix3{T}, t::Vector3{T})
RigidTransform(r::Matrix3{T}, t::Vector3{T})
```
Creates a new `RigidTransform{T}` from the given rotation `r` and translation `t`.

!!! note
    From the documentation of Rotations.jl:
    > The given `Matrix3{T}` should have the property `I =RR^T`, but this isn't enforced by the constructor.
"""
struct RigidTransform{T<:Real}
    rotation::RotMatrix3{T}
    translation::Vector3{T}

    @inline function RigidTransform(r::RotMatrix3{T}, t::Vector3{T}) where T
        new{T}(r, t)
    end

    @inline function RigidTransform(r::Matrix3{T}, t::Vector3{T}) where T
        new{T}(RotMatrix3(r), t)
    end

end

"""
    translate!(::AtomTable{T}, t::Vector3{T})
    translate!(::AbstractAtomContainer{T}, t::Vector3{T})

Translates all atoms of the given container according to the given translation vector `t`.
"""
@inline function translate!(at::AtomTable{T}, t::Vector3{T}) where T
    at.r .+= Ref(t)
    at
end

@inline function translate!(ac::AbstractAtomContainer{T}, t::Vector3{T}) where T
    translate!(atoms(ac), t)
    ac
end

"""
    rigid_transform!(at::AtomTable{T}, transform::RigidTransform{T})
    rigid_transform!(ac::AbstractAtomContainer, transform::RigidTransform)

Applies the rotation and the translation represented by `transform` (in this order) to all
atoms of the given container.
"""
@inline function rigid_transform!(at::AtomTable{T}, transform::RigidTransform{T}) where T
    at.r .= Ref(transform.rotation) .* at.r .+ Ref(transform.translation)
    at
end

@inline function rigid_transform!(ac::AbstractAtomContainer, transform::RigidTransform)
    rigid_transform!(atoms(ac), transform)
    ac
end

"""
    $(TYPEDSIGNATURES)

Computes the root mean square deviation ([RMSD](https://en.wikipedia.org/wiki/Root-mean-square_deviation_of_atomic_positions)) of the given `AbstractAtomBijection`.
"""
function compute_rmsd(f::AbstractAtomBijection{T}) where {T<:Real}
    atoms_A, atoms_B = atoms(f)
    r_BA = atoms_A.r .- atoms_B.r
    sqrt(mean(map(r -> transpose(r) * r, r_BA)))
end

"""
    $(TYPEDSIGNATURES)

Computes the root mean square deviation ([RMSD](https://en.wikipedia.org/wiki/Root-mean-square_deviation_of_atomic_positions)) based on two sets of atoms.

!!! note
    AtomContainers must have the same number of atoms.
"""
function compute_rmsd(A::AbstractAtomContainer, B::AbstractAtomContainer)
    sqrt(mean(squared_norm.(atoms(A).r .- atoms(B).r)))
end

"""
    $(TYPEDSIGNATURES)

Computes the transformation required to map two atom sets given as the atom bijection.

Returns a `RigidTransformation` object. The translation is given by the difference of the means of the atom sets.
The corresponding rotation matrix can be computed by the approach of [Coutsias et al.](https://doi.org/10.1002/jcc.20110) (default) or [Kabsch](https://doi.org/10.1107/S0567739476001873),
implemented by `RMSDMinimizerCoutsias` and `RMSDMinimizerKabsch`, respectively.  Both implementation rely on solving an eigen value problem.
Coutsias et al. represents rotation matrices as quaternions (use of Package Quaternions.jl).

!!! note
    In order to map the two atom sets with the resulting `RigidTransform` the system to be mapped hast to be transferred to the origin first (before the `RigidTransform` is applied).
"""
function compute_rmsd_minimizer(f::AbstractAtomBijection{T}, mini::Type{<: AbstractRMSDMinimizer}=RMSDMinimizerCoutsias) where {T<:Real}
    atoms_A, atoms_B = atoms(f)
    mean_A = mean(atoms_A.r)
    mean_B = mean(atoms_B.r)

    R = mapreduce(t -> t[1] * transpose(t[2]), +, zip(atoms_B.r .- Ref(mean_B), atoms_A.r .- Ref(mean_A)))

    rot_matrix = _compute_rotation(R, mini)

    RigidTransform(rot_matrix, mean_B - mean_A)
    
end

"""
    $(TYPEDSIGNATURES)

Computes the rotation matrix by solving the eigen value problem given as the correlation matrix `C`.
Uses all resulting eigenvalues and eigenvectors.
Warns if the correlation matrix is not positive definit (contains negative eigenvalues or eigenvalues equal to 0)
and uses the alternative approch `RMSDMinimizerCoutsias` instead.
Returns a `RotMatrix3`.
"""
function _compute_rotation(R::Matrix3{T}, ::Type{RMSDMinimizerKabsch}) where {T<:Real}
   
    C = Hermitian(transpose(R) * R)
    μ, a = eigen(C)

    # check eigen values for 
    if minimum(μ) <= 0
        @warn("Correlation matrix not positive definit. Rotation Matrix will be computed by Coutsias.")
        return _compute_rotation(R, RMSDMinimizerCoutsias)
    end

    RotMatrix3{T}(mapreduce(i -> 1/√μ[i] * (R * a[:, i]) * transpose(a[:, i]), +, 1:3))
end

"""
    $(TYPEDSIGNATURES)

Computes the rotation matrix by solving the eigen value problem given as the residual matrix `F`.
Uses only the largest of the resulting eigenvalues to generate the Quaternion describing the 
optimal rotation that maps the atoms onto each other.
Returns a `RotMatrix3`.
"""
function _compute_rotation(R::Matrix3{T}, ::Type{RMSDMinimizerCoutsias}) where {T<:Real}
    # Residual matrix F
    F = zeros(4,4)
    F[1,1] = R[1,1] + R[2,2] + R[3,3]
    F[2,1] = R[2,3] - R[3,2]
    F[3,1] = R[3,1] - R[1,3]
    F[4,1] = R[1,2] - R[2,1]

    F[1,2] = R[2,3] - R[3,2]
    F[2,2] = R[1,1] - R[2,2] - R[3,3]
    F[3,2] = R[1,2] + R[2,1]
    F[4,2] = R[1,3] + R[3,1]

    F[1,3] = R[3,1] - R[1,3]
    F[2,3] = R[1,2] + R[2,1]
    F[3,3] = -R[1,1] + R[2,2] - R[3,3]
    F[4,3] = R[2,3] + R[3,2]

    F[1,4] = R[1,2] - R[2,1]
    F[2,4] = R[1,3] + R[3,1]
    F[3,4] = R[2,3] + R[3,2]
    F[4,4] = -R[1,1] - R[2,2] + R[3,3]

    μ, a = eigen(F)

    q_max, i = findmax(μ)

    q_r = QuatRotation(quat(a[1,i], a[2,i], a[3,i], a[4,i]))

    RotMatrix3{T}(q_r)

end

"""
    $(TYPEDSIGNATURES)

Maps `AbstractAtomContainer` `A` onto `AbstractAtomContainer` `B`
by first moving `A` to the origin and then computing the `RigidTransform` by using `RMSDMinimizerCoutsias`.
Returns the mapped `AbstractAtomContainer` `A`.
"""
function map_rigid!(A::AbstractAtomContainer{T}, B::AbstractAtomContainer{T}; heavy_atoms_only::Bool = false) where {T<:Real}
    # first map proteins onto the origin
    atoms(A).r .= atoms(A).r .- Ref(mean(atoms(A).r))
    atoms_A = atoms(A)
    if heavy_atoms_only
        atoms_A = filter(atom -> atom.element != Elements.H, atoms_A)
    end

    rt = compute_rmsd_minimizer(TrivialAtomBijection(atoms_A, B))

    rigid_transform!(A, rt)

    A
end

"""
    $(TYPEDSIGNATURES)

The transformation maps
 1. the point `w1` onto the point `v1` and
 2. the point `w2` onto the ray that starts in `v1` and goes through `v2`
 3. the point `w3` into the plane generated by `v1`, `v2` and `v3`
"""
function match_points(
        w1::Vector3{T}, w2::Vector3{T}, w3::Vector3{T},
        v1::Vector3{T}, v2::Vector3{T}, v3::Vector3{T}) where {T<:Real}
    ϵ = T(0.00001)
    ϵ₂ = T(0.00000001)

    # Compute the translations that map v1 and w1 onto the origin 
    # and apply them to v2, v3 and w2, w3.
    tw2 = w2 - w1
    tw3 = w3 - w1

    tv2 = v2 - v1
    tv3 = v3 - v1

    dist_v2_v1 = squared_norm(tv2)
    dist_w2_w1 = squared_norm(tw2)
    dist_w3_w1 = squared_norm(tw3)
    dist_v3_v1 = squared_norm(tv3)

    # Try to remove nasty singularities arising if the first two
    # points in each point set are too close to each other:
    #   (a) ensure (v2 != v1) 
    if ((dist_v2_v1 < ϵ₂) && (dist_v3_v1 >= ϵ₂))
        tv3, tv2 = tv2, tv3
    end

    #   (b) ensure (w2 != w1) 
    if ((dist_w2_w1 < ϵ₂) && (dist_w3_w1 >= ϵ₂))
        tw3, tw2 = tw2, tw3
    end

    # initialize translation
    final_translation = -w1
    final_rotation = T(1)I(3)

    if ((squared_norm(tv2) >= ϵ₂) && (squared_norm(tw2) >= ϵ₂))
        # calculate the rotation axis: orthogonal to tv2 and tw2
        tw2 = normalize(tw2)
        tv2 = normalize(tv2)

        rotation_axis = tw2 + tv2

        rotation = if (squared_norm(rotation_axis) < ϵ)
            # the two axes seem to be antiparallel -
            # invert the second vector
            T(-1)I(3)
        else
            # rotate around the rotation axis
            AngleAxis{T}(π, rotation_axis...)
        end

        tw2 = rotation * tw2
        tw3 = rotation * tw3

        final_rotation    = rotation * final_rotation
        final_translation = rotation * final_translation

        if ((squared_norm(tw3) > ϵ₂) && (squared_norm(tv3) > ϵ₂))
            tw3 = normalize(tw3)
            tv3 = normalize(tv3)

            axis_w = cross(tv2, tw3)
            axis_v = cross(tv2, tv3)

            if ((squared_norm(axis_v) > ϵ₂) && (squared_norm(axis_w) > ϵ₂))
                axis_v = normalize(axis_v)
                axis_w = normalize(axis_w)

                rotation_axis = cross(axis_w, axis_v)

                if (squared_norm(rotation_axis) < ϵ₂)
                    scalar_prod = dot(axis_w, axis_v)
                    rotation = if (scalar_prod < 0.0)
                        AngleAxis{T}(π, tv2...)
                    else
                        T(1)I(3)
                    end
                else
                    # Compute the rotation that maps tw3 onto tv3
                    product = dot(axis_w, axis_v)
                    product = min(T(1.0), max(T(-1.0), product))

                    angle = acos(product)
                    rotation = if (angle > ϵ)
                        AngleAxis{T}(angle, rotation_axis...)
                    else
                        # Use the identity matrix instead.
                        T(1.0)I(3)
                    end
                end

                final_rotation    = rotation * final_rotation
                final_translation = rotation * final_translation
            end
        end
    end

    # apply the translation onto v1
    final_translation += v1

    # done
    return final_translation, final_rotation
end
