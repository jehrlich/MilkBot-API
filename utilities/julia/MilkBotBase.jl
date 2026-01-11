
using Printf, StructTypes, JSON3
export MilkPt, Lactation, LactationSet, Params, Priors, FitOptions, PriorsTree, Fit, FittingJob, Error, FittingResult, Credentials, ND, Version, PriorsBranch, PriorsLeaf, FilterableLeaf, LacFilter

#define object types ************************************
"Personal credentials for using MilkBot server"
@kwdef mutable struct Credentials
    server::String
    apikey::String
end

"Parameter set describing a laction curve using MilkBot model"
@kwdef struct Params
    scale::Float16
    ramp::Float16
    decay::Float16
    offset::Float16
    milkUnit::Union{String,Nothing} = "kg"
end
toString(p::Params) =
    sprintf("parameters: %.1f, %.1f, %.4f, %.1f", p.scale, p.ramp, p.decay, p.offset)

"a Normal distribution specified by mean and standard deviation"
@kwdef struct ND
    mean::Float16
    sd::Float16
end

"Prior expectations for mean and standard deviations of parameter values in a population"
@kwdef struct Priors
    scale::ND
    ramp::ND
    decay::ND
    offset::ND
    seMilk::Float16
    milkUnit::Union{String,Nothing} = "kg"
end

"a tree structure for Priors used by the fitter to find Priors for a lactation based values in specified fields"
abstract type PriorsTree end

"the type of filter, defining the matching method used"
struct LacFilter
    _type::String
    value::Union{Float16,String}
end

"a branching point in parsing the tree"
struct FilterableLeaf
    filter::LacFilter
    node::PriorsTree
end

"terminus specifying Priors to use"
struct PriorsLeaf <: PriorsTree
    _type::String
    node::Priors
end

"A branch of the tree, or the root"
struct PriorsBranch <: PriorsTree
    _type::String
    fieldName::String
    node::Vector{FilterableLeaf}
    default::Union{PriorsBranch,PriorsLeaf,Nothing}
end

"daily milk production in the unit specified by Lactation.milkUnit"
@kwdef struct MilkPt
    dim::Integer
    milk::Float64
end

"one lactation for one animal"
@kwdef struct Lactation
    lacKey::String
    breed::String
    parity::Integer
    points::Array{MilkPt}
    milkUnit::String = "kg"
end

"data returned by the server from a successful fitting"
struct Fit
    lactation::Union{Lactation,Nothing}
    lacKey::String
    fittedParams::Params
    n::Int
    distance::Float64
    seMilk::Float64
    priors::Priors
    fittingPath::Union{Vector{Params},Nothing}
    discriminatorPath::Union{String,Nothing}
end

"various options requested from the fitter (defaults here are verbose, unlike fitter defaults 
which will be used if no FitOptions are supplied in a request)"
@kwdef struct FitOptions
    returnInputData::Bool = true
    returnDiscriminatorPath::Bool = true
    returnFitPath::Bool = true
    fitEngine::String = "AnnealingFitter@2.0"
    fitObjective::String = "MB1@2.0"
    preferredMilkUnit::String = "kg"
end

"an error returned by the fitEngine"
@kwdef struct Error
    errorType::Union{String,Nothing} = nothing
    title::String
    status::Int
    detail::Union{String,Nothing} = nothing
    instance::Union{String,Nothing} = nothing
end

"data returned by the fitEngine for an array of multiple lactations"
@kwdef struct FittingResult
    fits::Vector{Fit}
    errors::Vector{Error}
    fitEngine::String
end

"a group of lactations"
@kwdef struct LactationSet
    name::String = "no name"
    lactations::Array{Lactation}
end

"data in a request to fit multiple lactations"
@kwdef struct FittingJob
    lactationSet::LactationSet
    priorsTree::Union{PriorsTree,Nothing} = nothing
    options::Union{FitOptions,Nothing} = nothing
end

"data returned by server responding to GET /version"
@kwdef struct Version
    serverVersion::String
    apiVersion::String
    admin::String
    accepteMilkUnits::Vector{String}
    defaultPriorsTree::PriorsTree
    defaultFitter::String
    availableFitters::Vector{String}
    message::String
end

#used by JSON3 for type<>Json
StructTypes.StructType(::Type{Version}) = StructTypes.Struct()
StructTypes.StructType(::Type{MilkPt}) = StructTypes.Struct()
StructTypes.StructType(::Type{ND}) = StructTypes.Struct()
StructTypes.StructType(::Type{Lactation}) = StructTypes.Struct()
StructTypes.StructType(::Type{LactationSet}) = StructTypes.Struct()
StructTypes.StructType(::Type{Params}) = StructTypes.Struct()
StructTypes.StructType(::Type{Priors}) = StructTypes.Struct()
StructTypes.StructType(::Type{Fit}) = StructTypes.Struct()
StructTypes.StructType(::Type{FitOptions}) = StructTypes.Struct()
StructTypes.StructType(::Type{LacFilter}) = StructTypes.Struct()
StructTypes.StructType(::Type{FilterableLeaf}) = StructTypes.Struct()
StructTypes.StructType(::Type{PriorsTree}) = StructTypes.AbstractType()
StructTypes.StructType(::Type{PriorsLeaf}) = StructTypes.Struct()
StructTypes.StructType(::Type{PriorsBranch}) = StructTypes.Struct()
StructTypes.subtypekey(::Type{PriorsTree}) = :_type
StructTypes.subtypes(::Type{PriorsTree}) = (priorsbranch=PriorsBranch, priorsleaf=PriorsLeaf)
StructTypes.StructType(::Type{FittingJob}) = StructTypes.Struct()
StructTypes.omitempties(::Type{FittingJob}) = (:priorsTree, :options)
StructTypes.StructType(::Type{Error}) = StructTypes.Struct()
StructTypes.StructType(::Type{FittingResult}) = StructTypes.Struct()
StructTypes.StructType(::Type{Credentials}) = StructTypes.Struct()

"MilkBot lactation function"
const predictedMilk(p::Params) = t -> ((1 - ℯ^((p.offset - t) / p.ramp) / 2) * p.scale) / ℯ^(p.decay * t)

"MilkBot lactation function"
predictedMilk(f::Fit) = predictedMilk(f.fittedParams)



"a GET request to server, does not require an API key"
const tryGet(server::String, path::String) =
    try
        response = HTTP.get("$(server)/$(path)")
        response.body
    catch e
        return "GET failed : $e"
    end

"GET server version"
const getVersion(cred::Credentials)::Version =
    JSON3.read(tryGet(cred.server, "version"), Version)

"GET default PriorsTree"
const getDefaultPriors(cred::Credentials)::PriorsTree =
    JSON3.read(tryGet(cred.server, "priorstree"), PriorsTree)

"POST request with JSON body and API key in header"
tryPost(cred::Credentials, path::String, body::String) =
    try
        response = HTTP.post("$(cred.server)/$(path)",
            Dict("X-API-KEY" => cred.apikey), body)
        response.body
    catch e
        return "POST failed, : $e"
    end

"Fit  MilkBot model to a lactation"
const fitLactation(cred::Credentials, lac::Lactation)::Fit =
    JSON3.read(tryPost(cred, "fitLactation", JSON3.write(Dict("lactation" => lac))), Fit)

"Fit  MilkBot model to a lactation"
const fitLactation(cred::Credentials, lac::Lactation, priors::Priors) =
    JSON3.read(tryPost(cred, "fitLactation", JSON3.write(Dict("lactation" => lac, "priors" => priors))), Fit)

"Fit  MilkBot model to a lactation"
const fitLactation(cred::Credentials, lac::Lactation, options::FitOptions) =
    JSON3.read(tryPost(cred, "fitLactation", JSON3.write(Dict("lactation" => lac, "options" => options))), Fit)

"Fit  MilkBot model to a lactation"
const fitLactation(cred::Credentials, lac::Lactation, priors::Priors, options::FitOptions) =
    JSON3.read(tryPost(cred, "fitLactation", JSON3.write(Dict("lactation" => lac, "priors" => priors, "options" => options))), Fit)

    "Fit all the lactations in a `FittingJob` returning a `FittingResult`"
const fitLactationSet( cred::Credentials, fj::FittingJob) ::Union{FittingResult,String} = 
	JSON3.read(tryPost(cred, "fitLactations", JSON3.write("fittingJob" => fj)),FittingResult )