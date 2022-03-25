module Milkbot

using  CSV, HTTP, StructTypes,  Plots, DataFrames, JSON3, TensorCast, Setfield, Printf 
export MilkPoint, Lactation, FittedLactation, LactationSet, MBParams, Fit, Priors, FitOptions, FittingJob, Credentials  #, StructTypes.StructType
export getPriorsTree, fitLactation, fitLactationSet, mbParamsArray, milkbot, lactationPlot, paramsPlot, refitPlot, fitPlot

struct Credentials 
    server::String
    apikey::String
end

struct MilkPoint 
    dim::Integer
    milk::Float64
end
MilkPoint((dim,milk)) = MilkPoint(dim,milk)

struct Lactation
    lacKey::String
    breed::String
    parity::Integer
    points #::Vector{MilkPoint} 
#    Lactation(a,b,c,d) = new(Lactation(a,b,c,d))
end

struct MBParams
    scale::Float16
    ramp::Float16
    decay::Float16
    offset::Float16
end
MBParams(js ::JSON3.Object{Base.CodeUnits{UInt8, String}, SubArray{UInt64, 1, Vector{UInt64}, Tuple{UnitRange{Int64}}, true}}) = MBParams(js.scale,js.ramp,js.decay,js.offset)
MBParams(d::Dict) = MBParams(d["scale"],d["ramp"],d["decay"],d["offset"])

const mbParamsArray(p::MBParams) = [p.scale, p.ramp,p.decay,p.offset]

struct Fit
    lacKey::String
    params::MBParams
    n
    sdResiduals
    path #::Union{nothing  Vector{MBParams}#:: JSON3.Array{JSON3.Object, Base.CodeUnits{UInt8, String}, SubArray{UInt64, 1, Vector{UInt64}, Tuple{UnitRange{Int64}}, true}}
#    Fit(a,b,c,d,e)=new(a,b,c,d,e)
#    Fit(js::JSON3.Object{Base.CodeUnits{UInt8, String}, Vector{UInt64}})=Fit(js.lacKey, MBParams(js.params), js.n, js.sdResiduals, js.path)
end

struct FittedLactation
    lac:: Lactation
    fit:: Fit
end    

struct Priors
    means::MBParams
    sd::MBParams
    seMilk::Float16
    milkUnit::String
    # Priors(a,b,c,d) = new(Priors(a,b,c,d))
end
# Priors(js::JSON3.Object{Base.CodeUnits{UInt8, String}, SubArray{UInt64, 1, Vector{UInt64}, Tuple{UnitRange{Int64}}, true}}) = 
# new(Priors(MBParams(js.means), MBParams(js.sd), js.seMilk,js.milkUnit))

struct FitOptions
    steppedFit::Bool
    returnInputData::Bool
    returnPriors::Bool
    returnPath::Bool
    fitMethod::String  #: String = "MilkBot@2.01",
    preferredMilkUnit::String #: MilkUnit = Kg
   # FitOptions(a,b,c,d,e,f)= new(FitOptions(a,b,c,d,e,f))
  #  FitOptions(a,b,c,d ) = FitOptions(a,b,c,d,"MilkBot@2.01","Kg")
 end
const trackedOptions = FitOptions(false,false,false,true,"MilkBot@2.01","Kg")

struct LactationSet
    name #: Option[String],
    lactations #: Seq[Lactation],
    milkUnit #: Option[MilkUnit.Value]
    LactationSet(a,b,c) = new(LactationSet(a,b,c))
    LactationSet(s::Vector{Lactation}) = LactationSet("testSet", s, "Kg")
end

struct FittingJob
    lactationSet::LactationSet
    priorsTree 
    options 
    FittingJob(a,b,c) = new(FittingJob(a,b,c))
    FittingJob(s::LactationSet) = FittingJob(s,nothing,nothing)
end
const TrackedFittingJob(l::Lactation) = FittingJob(LactationSet([l]),nothing,trackedOptions)

StructTypes.StructType(::Type{FittingJob}) = StructTypes.Struct()
StructTypes.StructType(::Type{LactationSet}) = StructTypes.Struct()
StructTypes.StructType(::Type{Lactation}) = StructTypes.Struct()
StructTypes.StructType(::Type{MilkPoint}) = StructTypes.Struct()
StructTypes.StructType(::Type{FitOptions}) = StructTypes.Struct()
StructTypes.StructType(::Type{Priors}) = StructTypes.Struct()
StructTypes.StructType(::Type{MBParams}) = StructTypes.Struct()
StructTypes.StructType(::Type{Fit}) = StructTypes.Struct()

const getPriorsTree(cred::Credentials) =
begin    
    try
        response = HTTP.get("$(cred.server)/priorstree?milkUnit=Kg", Dict("X-API-KEY"=>cred.apikey))
        return String(response.body)
    catch e
        return "Error occurred : $e"
    end
end

const fitLactation(lac::Lactation, cred::Credentials) =
begin
    jsbody = JSON3.write("lactation" => lac)
    try
        response = HTTP.post("$(cred.server)/fitlactation?includePath=true", Dict("X-API-KEY"=>cred.apikey),jsbody)
        return String(response.body)
    catch e
        return "Error occurred : $e"
    end    
end

const fitLactation(lac::Lactation, priors::Priors, cred::Credentials) =
begin
    jsbody = JSON3.write(Dict("lactation" => lac, "priors" => priors))
    try
        response = HTTP.post("$(cred.server)/fitlactation?includePath=true", Dict("X-API-KEY"=>cred.apikey),jsbody)
        return String(response.body)
    catch e
        return "Error occurred : $e"
    end    
end

const fitLactationSet(fj::FittingJob, cred::Credentials) =
begin
    jsbody = JSON3.write("fittingJob" => fj)
    try
        response = HTTP.post("$(cred.server)/fitlactations", Dict("X-API-KEY"=>cred.apikey),jsbody)
        return String(response.body)
    catch e
        return "Error occurred : $e"
    end    
end


#const milkbot(r::RowTypeSitko) = t ->  ((1 - ℯ^((r.offset - t)/r.ramp)/2)*r.scale)/ℯ^(r.decay * t) 
const milkbot(f::Fit) = t ->  ((1 - ℯ^((f.params.offset - t)/f.params.ramp)/2)*f.params.scale)/ℯ^(f.params.decay * t) 
const milkbot(p:: MBParams) = t ->  ((1 - ℯ^((p.offset - t)/p.ramp)/2)*p.scale)/ℯ^(p.decay * t) 

const lactationPlot(fl::FittedLactation) = 
 begin
    dim = map(m -> m.dim, fl.lac.points)
    milk = map(m -> m.milk, fl.lac.points)
    plot(dim  ,milk, seriestype = :scatter, color = :black, label = fl.lac.lacKey)
    plot!(milkbot(fl.fit),0,maximum(dim), label = "fit")
 end

 const paramsPlot(fit::Fit, priors::Priors) = 
 begin 
     data = [
        map(d->(d["scale"]-priors.means.scale)/priors.sd.scale,fit.path),
        map(d->(d["ramp"]-priors.means.ramp +.004)/priors.sd.ramp,fit.path),
        map(d->(d["decay"]-priors.means.decay)/priors.sd.decay,fit.path),
        map(d->(d["offset"]-priors.means.offset-.004)/priors.sd.offset-.01,fit.path)
     ]
      plot(1:length(fit.path),data , labels = ["scale" "ramp" "decay" "offset"], legend=:topleft)
 end
 
 fitPlot(l::Lactation, priors::Priors, cred:: Credentials) = 
 begin
    dim = map(m -> m.dim, l.points)
    milk = map(m -> m.milk, l.points)
    fit = JSON3.read(fitLactation(l, priors, cred), Fit) #call to API to re-fit
    plot(dim,milk, seriestype = :scatter, label = l.lacKey) 
    s = map(p ->milkbot(MBParams(p)) , collect(fit.path)) #vector of mb functions
    plot!(pop!(s),0,maximum(dim), color = :black, linewidth =2, label = "final",
    annotate = (((.4, .15), (@sprintf("SE: %.2f", fit.sdResiduals), 10,:right))))
    p1 = plot!(s[1:min(12, length(s))],0,maximum(dim), label = "")
    p2 =   paramsPlot(fit, priors) 
    df = vcat(DataFrame.(fit.path)...)
    plot(p1,p2, layout = (2,1), size = (600,600))
    #vcat(DataFrame.(reFit.path)...)
 end

 #version including API call
 const refitPlot(fl::FittedLactation, priors::Priors, cred:: Credentials) = 
 begin
    dim = map(m -> m.dim, fl.lac.points)
    milk = map(m -> m.milk, fl.lac.points)
    reFit = JSON3.read(fitLactation(fl.lac, priors, cred), Fit) #call to API to re-fit
    plot(dim, milk, seriestype = :scatter, label = fl.lac.lacKey)
    plot!(milkbot(fl.fit),0,maximum(dim), label = "original fit", linestyle = :dash, color = :black, linewidth =2,
    annotate = (((.4, .25), ("original SE: $(fl.fit.sdResiduals)", 10, :right))))
    s = map(p ->milkbot(MBParams(p)) , collect(reFit.path)) #vector of mb functions
    plot!(pop!(s),0,maximum(dim), color = :black, linewidth =2, label = "re-fit",
    annotate = (((.4, .15), (@sprintf("refit SE: %.2f", reFit.sdResiduals), 10,:right))))
    p1 = plot!(s[1:min(12, length(s))],0,maximum(dim), label = "")
    p2 =   paramsPlot(reFit, priors) 
    df = vcat(DataFrame.(reFit.path)...)
    plot(p1,p2, layout = (2,1), size = (600,600))
    #vcat(DataFrame.(reFit.path)...)
 end

  #no API call
 const refitPlot(fl::FittedLactation, reFit:: Fit) = 
 begin
    dim = map(m -> m.dim, fl.lac.points)
    milk = map(m -> m.milk, fl.lac.points)
    plot(dim  , milk, seriestype = :scatter, label = fl.lac.lacKey)
    plot!(milkbot(fl.fit),0,maximum(dim), label = "original fit", linestyle = :dash, color = :black, linewidth =2)
    s = map(p ->milkbot(MBParams(p)) , collect(reFit.path)) #vector of mb functions
    plot!(pop!(s),0,maximum(dim), color = :black, linewidth =2, label = "re-fit")
    p1 = plot!(s[1:min(12, length(s))],0,maximum(dim), label = "")
    p2 =   paramsPlot(reFit, priors) 
    df = vcat(DataFrame.(reFit.path)...)
    plot(p1,p2, layout = (2,1), size = (600,600))
 end

end #Milkbot module
