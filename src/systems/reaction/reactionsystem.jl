struct Reaction{S <: Variable, T <: Number}
    rate
    substrates::Vector{Operation}
    products::Vector{Operation}
    substoich::Vector{T}
    prodstoich::Vector{T}
    netstoich::Vector{Pair{S,T}}
    only_use_rate::Bool
end

function Reaction(rate, subs, prods, substoich, prodstoich;
                  netstoich=nothing, only_use_rate=false, kwargs...)

      (isnothing(prods)&&isnothing(subs)) && error("A reaction requires a non-nothing substrate or product vector.")
      (isnothing(prodstoich)&&isnothing(substoich)) && error("Both substrate and product stochiometry inputs cannot be nothing.")
      if isnothing(subs)
        subs = Vector{Operation}()
        (substoich!=nothing) && error("If substrates are nothing, substrate stiocihometries have to be so too.")
        substoich = typeof(prodstoich)()
    end
    if isnothing(prods)
        prods = Vector{Operation}()
        (prodstoich!=nothing) && error("If products are nothing, product stiocihometries have to be so too.")
        prodstoich = typeof(substoich)()
    end
    ns = isnothing(netstoich) ? get_netstoich(subs, prods, substoich, prodstoich) : netstoich
    Reaction(rate, subs, prods, substoich, prodstoich, ns, only_use_rate)
end


# three argument constructor assumes stoichiometric coefs are one and integers
function Reaction(rate, subs, prods; kwargs...)

    sstoich = isnothing(subs) ? nothing : ones(Int,length(subs))
    pstoich = isnothing(prods) ? nothing : ones(Int,length(prods))
    Reaction(rate, subs, prods, sstoich, pstoich; kwargs...)
end

# calculates the net stoichiometry of a reaction as a vector of pairs (sub,substoich)
function get_netstoich(subs, prods, sstoich, pstoich)
    # stoichiometry as a Dictionary
    nsdict = Dict{Variable,eltype(sstoich)}(sub.op => -sstoich[i] for (i,sub) in enumerate(subs))
    for (i,p) in enumerate(prods)
        coef = pstoich[i]
        prod = p.op
        @inbounds nsdict[prod] = haskey(nsdict, prod) ? nsdict[prod] + coef : coef
    end

    # stoichiometry as a vector
    ns = [el for el in nsdict if el[2] != zero(el[2])]

    ns
end

struct ReactionSystem <: AbstractSystem
    eqs::Vector{Reaction}
    iv::Variable
    states::Vector{Variable}
    ps::Vector{Variable}
    name::Symbol
    systems::Vector{ReactionSystem}
end

function ReactionSystem(eqs, iv, species, params; systems = ReactionSystem[],
                                                  name = gensym(:ReactionSystem))

    ReactionSystem(eqs, iv, convert.(Variable,species), convert.(Variable,params),
                   name, systems)
end

# Calculate the ODE rate law
function oderatelaw(rx)
    @unpack rate, substrates, substoich, only_use_rate = rx
    rl = rate
    if !only_use_rate
        coef = one(eltype(substoich))
        for (i,stoich) in enumerate(substoich)
            coef *= factorial(stoich)
            rl   *= isone(stoich) ? substrates[i] : substrates[i]^stoich
        end
        (!isone(coef)) && (rl /= coef)
    end
    rl
end

function assemble_drift(rs)
    D   = Differential(rs.iv())
    eqs = [D(x(rs.iv())) ~ 0 for x in rs.states]
    species_to_idx = Dict((x => i for (i,x) in enumerate(rs.states)))

    for rx in rs.eqs
        rl = oderatelaw(rx)
        for (spec,stoich) in rx.netstoich
            i = species_to_idx[spec]
            if iszero(eqs[i].rhs)
                signedrl = (stoich > zero(stoich)) ? rl : -rl
                rhs      = isone(abs(stoich)) ? signedrl : stoich * rl
            else
                Δspec = isone(abs(stoich)) ? rl : abs(stoich) * rl
                rhs   = (stoich > zero(stoich)) ? (eqs[i].rhs + Δspec) : (eqs[i].rhs - Δspec)
            end
            eqs[i] = Equation(eqs[i].lhs, rhs)
        end
    end
    eqs
end

function assemble_diffusion(rs)
    eqs = Expression[Constant(0) for x in rs.states, y in rs.eqs]
    species_to_idx = Dict((x => i for (i,x) in enumerate(rs.states)))

    for (j,rx) in enumerate(rs.eqs)
        rlsqrt = sqrt(oderatelaw(rx))
        for (spec,stoich) in rx.netstoich
            i            = species_to_idx[spec]
            signedrlsqrt = (stoich > zero(stoich)) ? rlsqrt : -rlsqrt
            eqs[i,j]     = isone(abs(stoich)) ? signedrlsqrt : stoich * rlsqrt
        end
    end
    eqs
end

function var2op(var)
    Operation(var,Vector{Expression}())
end

# Calculate the Jump rate law (like ODE, but uses X instead of X(t).
# The former generates a "MethodError: objects of type Int64 are not callable" when trying to solve the problem.
function jumpratelaw(rx; rxvars=get_variables(rx.rate))
    @unpack rate, substrates, substoich, only_use_rate = rx
    rl = rate
    for op in rxvars
        rl = substitute(rl, op => var2op(op.op))
    end
    if !only_use_rate
        for (i,stoich) in enumerate(substoich)
            rl *= isone(stoich) ? var2op(substrates[i].op) : Operation(binomial,[var2op(substrates[i].op),stoich])
        end
    end
    rl
end

# if haveivdep=false then time dependent rates will still be classified as mass action
function ismassaction(rx, rs; rxvars = get_variables(rx.rate), 
                              haveivdep = any(var -> isequal(rs.iv,convert(Variable,var)), rxvars))    
    return !(haveivdep || rx.only_use_rate || any(convert(Variable,rxv) in states(rs) for rxv in rxvars))
end

function assemble_jumps(rs)
    eqs = Vector{Union{ConstantRateJump, MassActionJump, VariableRateJump}}()

    for rx in equations(rs)
        rxvars    = get_variables(rx.rate)
        haveivdep = any(var -> isequal(rs.iv,convert(Variable,var)), rxvars)
        if ismassaction(rx, rs; rxvars=rxvars, haveivdep=haveivdep)            
            reactant_stoch = isempty(rx.substoich) ? [0 => 1] : [var2op(sub.op) => stoich for (sub,stoich) in zip(rx.substrates,rx.substoich)]
            net_stoch      = [Pair(var2op(p[1]),p[2]) for p in rx.netstoich]
            push!(eqs, MassActionJump(rx.rate, reactant_stoch, net_stoch))
        else
            rl     = jumpratelaw(rx, rxvars=rxvars)
            affect = Vector{Equation}()
            for (spec,stoich) in rx.netstoich
                push!(affect, var2op(spec) ~ var2op(spec) + stoich)
            end
            if haveivdep
                push!(eqs, VariableRateJump(rl,affect))
            else
                push!(eqs, ConstantRateJump(rl,affect))
            end
        end
    end
    eqs
end

function Base.convert(::Type{<:ODESystem},rs::ReactionSystem)
    eqs = assemble_drift(rs)
    ODESystem(eqs,rs.iv,rs.states,rs.ps,name=rs.name,
              systems=convert.(ODESystem,rs.systems))
end

function Base.convert(::Type{<:SDESystem},rs::ReactionSystem)
    eqs = assemble_drift(rs)
    noiseeqs = assemble_diffusion(rs)
    SDESystem(eqs,noiseeqs,rs.iv,rs.states,rs.ps,
              name=rs.name,systems=convert.(SDESystem,rs.systems))
end

function Base.convert(::Type{<:JumpSystem},rs::ReactionSystem)
    eqs = assemble_jumps(rs)
    JumpSystem(eqs,rs.iv,rs.states,rs.ps,name=rs.name,
              systems=convert.(JumpSystem,rs.systems))
end