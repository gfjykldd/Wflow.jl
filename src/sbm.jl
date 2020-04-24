const mv = NaN

Base.@kwdef struct SBM{T,N,M}
    maxlayers::Int              # Maximum number of soil layers
    nlayers::Int                # Number of soil layers
    cfmax::T                    # Degree-day factor [mm ᵒC⁻¹ Δt⁻¹]
    tt::T                       # Threshold temperature for snowfall [ᵒC]
    ttm::T                      # Threshold temperature for snowmelt [ᵒC]
    tti::T                      # Threshold temperature interval length [ᵒC]
    whc::T                      # Water holding capacity as fraction of current snow pack [-]
    cf_soil::T                  # Controls soil infiltration reduction factor when soil is frozen [-]
    w_soil::T                   # Soil temperature smooth factor [-]
    soilthickness::T            # Soil thickness [mm]
    infiltcapsoil::T            # Soil infiltration capacity [mm/Δt]
    infiltcappath::T            # Infiltration capacity of the compacted areas [mm Δt⁻¹]
    pathfrac::T                 # Fraction of compacted area  [-]
    waterfrac::T                # Fraction of open water (excluding rivers) [-]
    riverfrac::T                # Fraction of river [-]
    θₛ::T                       # Saturated water content (porosity) [mm mm⁻¹]
    θᵣ::T                       # Residual water content [mm mm⁻¹]
    hb::T                       # Air entry pressure [cm] of soil (Brooks-Corey)
    kv::T                       # Vertical hydraulic conductivity [mm Δt⁻¹]
    kvfrac::SVector{N,T}        # Muliplication factor [-] applied to kv (vertical flow)
    maxleakage::T               # Maximum leakage [mm/Δt] from saturated zone
    c::SVector{N,T}             # Brooks-Corey power coefﬁcient [-] for each soil layer
    m::T                        # Parameter [mm] controlling f
    f::T = (θₛ - θᵣ) / m        # A scaling parameter [mm⁻¹] (controls exponential decline of kv)
    capscale::T                 # Parameter [mm] controlling capilary rise
    rootdistpar::T              # Controls how roots are linked to water table [-]
    rootingdepth::T             # Rooting depth [mm]
    lai::T                      # Leaf area index [m² m⁻²]
    sl::T                       # Specific leaf storage [mm]
    kext::T                     # Extinction coefficient [-] (to calculate canopy gap fraction)
    swood::T                    # Storage woody part of vegetation [mm]
    cmax::T                     # Maximum canopy storage [mm]
    canopygapfraction::T        # Canopy gap fraction [-]
    e_r::T                      # Gash interception model parameter, ratio of the average evaporation from the wet canopy [mm Δt⁻¹] and the average precipitation intensity [mm Δt⁻¹] on a saturated canopy
    et_reftopot::T              # Multiplication factor [-] to correct
    altitude::T                 # Vertical elevation [m]
    precipitation::T = mv       # Precipitation [mm]
    temperature::T = mv         # Temperature [ᵒC]
    potevap::T = mv             # Potential evapotranspiration [mm]
    pottrans_soil::T = mv       # Potential transpiration, open water, river and soil evaporation (after subtracting interception from potevap)
    transpiration::T = mv       # Transpiration [mm]
    ae_ustore::T = mv           # Actual evaporation from unsaturated store [mm]
    ae_sat::T = mv              # Actual evaporation from saturated store [mm]
    interception::T = mv        # Interception [mm]
    soilevap::T = mv            # Soil evaporation [mm]
    actevapsat::T = mv          # Actual evaporation from saturated store (transpiration and soil evaporation) [mm]
    actevap::T = mv             # Total actual evaporation (transpiration + soil evapation + open water evaporation) [mm]
    ae_openw_l::T = mv          # Actual evaporation from open water (land) [mm]
    ae_openw_r::T = mv          # Actual evaporation from river [mm]
    avail_forinfilt::T = mv     # Water available for infiltration [mm]
    actinfilt::T = mv           # Actual infiltration into the unsaturated zone [mm]
    actinfiltsoil::T = mv       # Actual infiltration non-compacted fraction [mm]
    actinfiltpath::T = mv       # Actual infiltration compacted fraction [mm]
    excesswater::T = mv         # Water that cannot infiltrate due to saturated soil (saturation excess) [mm]
    excesswatersoil::T = mv     # Excess water for non-compacted fraction [mm]
    excesswaterpath::T = mv     # Excess water for compacted fraction [mm]
    ustorelayerdepth::SVector{N,T} = fill(0.0, SVector{N,T})
    act_thickl::SVector{N,T}    # Thickness of soil layers [mm]
    sumlayers::SVector{M,T}     # Cumulative sum of soil layers [mm], starting at soil surface (0)
    ustoredepth::T = mv         # Amount of available water in the unsaturated zone [mm]
    transfer::T = mv            # Downward flux from unsaturated to saturated zone [mm]
    capflux::T = mv             # Capilary rise [mm]
    recharge::T = mv            # Net recharge to saturated store [mm]
    soilwatercapacity::T = soilthickness * (θₛ - θᵣ)            # Soilwater capacity [mm]
    satwaterdepth::T = 0.85 * soilwatercapacity                 # Saturated store [mm]
    zi::T = max(0.0, soilthickness - satwaterdepth / (θₛ - θᵣ)) # Pseudo-water table depth [mm] (top of the saturated zone)
    snow::T = 0.0               # Snow storage [mm]
    snowwater::T = 0.0          # Liquid water content in the snow pack [mm]
    tsoil::T = 10.0             # Top soil temperature [ᵒC]
    canopystorage::T = 0.0      # Canopy storage [mm]
end

"""
    readnetcdf(nc, var, inds, dpars)

Read parameter `var` from NetCDF file `nc` for indices `inds`. If `var` is not
available, a default value based on dict 'dpars' is returned.
"""
function readnetcdf(nc, var, inds, dpars)
    if haskey(nc, var)
        @info(string("read parameter ", var))
        Float64.(nc[var][:][inds])
    else
        @warn(string(var, " not found, set to default value ", dpars[var]))
        fill(dpars[var], length(inds))
    end
end

"""
    statenames()

Returns Array{Symbol,1} for extracting model state fields from SBM struct.
"""
function statenames()

    # depends on ini file settings (optional: glaciers, snow, irrigation)
    states = [:satwaterdepth, :snow, :tsoil, :ustorelayerdepth, :snowwater, :canopystorage]
    #TODO: (warm) states read from netcdf file or cold state (reinit=1, setting in ini file)

end

"""
    set_layerthickness(d::Float64, sl::SVector)

Calculate actual soil thickness of layers based on a reference depth (e.g. soil depth or water table depth) `d`,
and a SVector `sl` with cumulative soil depth starting at soil surface (0).
"""
function set_layerthickness(d::Float64, sl::SVector)
    act_d = sl[sl.<d]
    if d - act_d[end] > 0
        push!(act_d, d)
    end
    diff(act_d)
end

"""
    initialize(staticmaps_path, leafarea_path)

Initial part of the SBM model concept. Reads model parameters from disk, `staticmaps_path` is the file path
of the NetCDF file with model parameters, `leafarea_path` is an optional file path for a NetCDF file with leaf
area index (LAI) values (climatology).
"""
function initialize(staticmaps_path, leafarea_path)

    # timestep that the parameter units are defined in
    basetimestep = Second(Day(1))
    Δt = Second(Day(1))
    sizeinmetres = false
    thicknesslayers = SVector(100.0, 300.0, 800.0)
    maxlayers = length(thicknesslayers) + 1 # max number of soil layers
    sumlayers = SVector(pushfirst(cumsum(thicknesslayers), 0.0))

    # default parameter values (dict)
    dparams = Dict(
        "Cfmax" => 3.75653 * (Δt / basetimestep),
        "TT" => 0.0,
        "TTM" => 0.0,
        "TTI" => 1.0,
        "WHC" => 0.1,
        "cf_soil" => 0.038,
        "w_soil" => 0.1125 * (Δt / basetimestep),
        "SoilThickness" => 2000.0,
        "InfiltCapSoil" => 100.0,
        "InfiltCapPath" => 10.0,
        "PathFrac" => 0.01,
        "WaterFrac" => 0.0,
        "thetaS" => 0.6,
        "thetaR" => 0.01,
        "AirEntryPressure" => 10.0,
        "KsatVer" => 3000.0 * (Δt / basetimestep),
        "MaxLeakage" => 0.0,
        "c" => 10.0,
        "M" => 300.0,
        "CapScale" => 100.0,
        "rootdistpar" => -500.0,
        "RootingDepth" => 750.0,
        "LAI" => 1.0,
        "Cmax" => 1.0,
        "CanopyGapFraction" => 0.1,
        "EoverR" => 0.1,
        "et_reftopot" => 1.0,
        "kvfrac" => 1.0,
    )

    nc = NCDataset(staticmaps_path)

    subcatch_2d = nc["wflow_subcatch"][:]
    # indices based on catchment
    inds = Wflow.active_indices(subcatch_2d, missing)
    n = length(inds)

    altitude = Float64.(nc["wflow_dem"][:][inds])
    river = nomissing(nc["wflow_river"][:], 0)[inds]
    riverwidth = Float64.(nc["wflow_riverwidth"][:][inds])
    ldd = Float64.(nc["wflow_ldd"][:][inds])
    if "wflow_riverlength" in keys(nc)
        riverlength = Float64.(nc["wflow_riverlength"][:][inds])
    else
        @warn("wflow_riverlength not found, riverlength based on ldd...")
        # TODO calculate river based on ldd
    end

    # read x, y coordinates and calculate cell length [m]
    y_nc = "y" in keys(nc.dim) ? nomissing(nc["y"][:]) : nomissing(nc["lat"][:])
    x_nc = "x" in keys(nc.dim) ? nomissing(nc["x"][:]) : nomissing(nc["lon"][:])
    y = repeat(y_nc', outer = (length(x_nc), 1))[inds]
    cellength = abs(mean(diff(x_nc)))

    # snow parameters (also set in ini file (snow=True or False)?)
    cfmax = readnetcdf(nc, "Cfmax", inds, dparams)
    tt = readnetcdf(nc, "TT", inds, dparams)
    tti = readnetcdf(nc, "TTI", inds, dparams)
    ttm = readnetcdf(nc, "TTM", inds, dparams)
    whc = readnetcdf(nc, "WHC", inds, dparams)
    w_soil = readnetcdf(nc, "w_soil", inds, dparams)
    cf_soil = readnetcdf(nc, "cf_soil", inds, dparams)

    # soil parameters
    θₛ = readnetcdf(nc, "thetaS", inds, dparams)
    θᵣ = readnetcdf(nc, "thetaR", inds, dparams)
    kv = readnetcdf(nc, "KsatVer", inds, dparams)
    m = readnetcdf(nc, "M", inds, dparams)
    hb = readnetcdf(nc, "AirEntryPressure", inds, dparams)
    soilthickness = readnetcdf(nc, "SoilThickness", inds, dparams)
    infiltcappath = readnetcdf(nc, "InfiltCapPath", inds, dparams)
    infiltcapsoil = readnetcdf(nc, "InfiltCapSoil", inds, dparams)
    maxleakage = readnetcdf(nc, "MaxLeakage", inds, dparams)
    #TODO: store c, kvfrac in staticmaps.nc start at index 1
    c = fill(dparams["c"], (maxlayers, n))
    kvfrac = fill(dparams["kvfrac"], (maxlayers, n))
    for i in [0:1:maxlayers-1;]
        if string("c_", i) in keys(nc)
            c[i+1, :] = Float64.(nc[string("c_", i)][:][inds])
        else
            @warn(string("c_", i, " not found, set to default value ", dparams["c"]))
        end
        if string("kvfrac_", i) in keys(nc)
            kvfrac[i+1, :] = Float64.(nc[string("kvfrac_", i)][:][inds])
        else
            @warn(string(
                "kvfrac_",
                i,
                " not found, set to default value ",
                dparams["kvfrac"],
            ))
        end
    end

    # fraction open water and compacted area (land cover)
    waterfrac = readnetcdf(nc, "WaterFrac", inds, dparams)
    pathfrac = readnetcdf(nc, "PathFrac", inds, dparams)

    # vegetation parameters
    rootingdepth = readnetcdf(nc, "RootingDepth", inds, dparams)
    rootdistpar = readnetcdf(nc, "rootdistpar", inds, dparams)
    capscale = readnetcdf(nc, "CapScale", inds, dparams)
    et_reftopot = readnetcdf(nc, "et_reftopot", inds, dparams)
    # cmax, e_r, canopygapfraction only required when lai climatoly not provided
    cmax = readnetcdf(nc, "Cmax", inds, dparams)
    e_r = readnetcdf(nc, "EoverR", inds, dparams)
    canopygapfraction = readnetcdf(nc, "CanopyGapFraction", inds, dparams)

    # if lai climatology provided use sl, swood and kext to calculate cmax
    if isnothing(leafarea_path) == false
        sl = readnetcdf(nc, "Sl", inds, dparams)
        swood = readnetcdf(nc, "Swood", inds, dparams)
        kext = readnetcdf(nc, "Kext", inds, dparams)
        # set in inifile? Also type (monthly, daily, hourly) as part of netcdf variable attribute?
        # in original inifile: LAI=staticmaps/clim/LAI,monthlyclim,1.0,1
        lai_clim = NCDataset(leafarea_path) #TODO:include LAI climatology in update() vertical SBM model
    end

    sbm = Vector{SBM}(undef, n)
    for i = 1:n
        act_thickl = set_layerthickness(soilthickness[i], sumlayers)
        nlayers = length(act_thickl)
        s_layers = pushfirst(cumsum(SVector{nlayers,Float64}(act_thickl)), 0.0)

        xl = sizeinmetres ? cellength : lattometres(y[i])[1] * cellength
        yl = sizeinmetres ? cellength : lattometres(y[i])[2] * cellength
        riverfrac =
            Bool(river[i]) ? min((riverlength[i] * riverwidth[i]) / (xl * yl), 1.0) : 0.0

        sbm[i] = SBM{Float64,nlayers,nlayers + 1}(
            maxlayers = maxlayers,
            nlayers = nlayers,
            riverfrac = riverfrac,
            cfmax = cfmax[i],
            tt = tt[i],
            tti = tti[i],
            ttm = ttm[i],
            whc = whc[i],
            w_soil = w_soil[i],
            cf_soil = cf_soil[i],
            θₛ = θₛ[i],
            θᵣ = θᵣ[i],
            kv = kv[i],
            kvfrac = kvfrac[1:nlayers, i],
            m = m[i],
            hb = hb[i],
            soilthickness = soilthickness[i],
            act_thickl = act_thickl,
            sumlayers = s_layers,
            infiltcappath = infiltcappath[i],
            infiltcapsoil = infiltcapsoil[i],
            maxleakage = maxleakage[i],
            waterfrac = max(waterfrac[i] - riverfrac, 0.0),
            pathfrac = pathfrac[i],
            altitude = altitude[i],
            rootingdepth = rootingdepth[i],
            rootdistpar = rootdistpar[i],
            capscale = capscale[i],
            et_reftopot = et_reftopot[i],
            sl = sl[i],
            swood = swood[i],
            kext = kext[i],
            c = c[1:nlayers, i],
            lai = 1.0,
            cmax = cmax[i],
            canopygapfraction = canopygapfraction[i],
            e_r = e_r[i],
        )

    end

    return sbm

end

function update(sbm::SBM)

    #start dummy variables (should be generated from model reader and from Config.jl TOML)
    lai = true
    glacierfrac = false
    modelsnow = true
    soilinfreduction = false
    transfermethod = 0
    potevap = 4.0
    precipitation = 3.0
    temperature = 10.0
    wl_land = 0.0 #from kinematic wave land
    wl_river = 0.10 #from kinematic river
    irsupply_mm = 0.0
    nrpaddyirri = 0
    ust = false
    Δt = Second(Day(1))
    #end dummpy variables

    if lai
        cmax = sbm.sl * sbm.lai + sbm.swood
        canopygapfraction = exp(-sbm.kext * sbm.lai)
        ewet = (1.0 - exp(-sbm.kext * sbm.lai)) * potevap
        e_r = precipitation > 0.0 ? min(0.25, ewet / max(0.0001, precipitation)) : 0.0
    end

    potevap = potevap * sbm.et_reftopot
    # should we include tempcor in SBM?
    # PotEvap = PotenEvap #??

    if Δt >= Hour(23)
        throughfall, interception, stemflow, canopystorage = rainfall_interception_gash(
            cmax,
            e_r,
            canopygapfraction,
            precipitation,
            sbm.canopystorage,
            maxevap = potevap,
        )
        pottrans_soil = max(0.0, potevap - interception) # now in mm
    else
        netinterception, throughfall, stemflow, leftover, interception, canopystorage =
            rainfall_interception_modrut(
                precipitation,
                potevap,
                sbm.canopystorage,
                canopygapfraction,
                cmax,
            )
        pottrans_soil = max(0.0, leftover)  # now in mm
        interception = netinterception
    end

    eff_precipitation = throughfall + stemflow

    if modelsnow
        tsoil = sbm.tsoil + sbm.w_soil * (temperature - sbm.tsoil)
        snow, snowwater, snowmelt, rainfallplusmelt, snowfall = snowpack_hbv(
            sbm.snow,
            sbm.snowwater,
            eff_precipitation,
            temperature,
            sbm.tti,
            sbm.tt,
            sbm.ttm,
            sbm.cfmax,
            sbm.whc,
        )
        if glacierfrac
            # Run Glacier module and add the snowpack on-top of it.
            # Estimate the fraction of snow turned into ice (HBV-light).
            # Estimate glacier melt.

            snow, snow2glacier, glacierstore, glaciermelt = glacier_hbv(
                sbm.glacierfrac,
                sbm.glacierstore,
                sbm.snow,
                temperature,
                sbm.g_tt,
                sbm.g_cfmax,
                sbm.g_sifrac,
                Δt,
                basetimestep,
            )
            # Convert to mm per grid cell and add to snowmelt
            glaciermelt = glaciermelt * sbm.glacierfrac
            rainfallplusmelt = rainfallplusmelt + glaciermelt

        end
    else
        rainfallplusmelt = eff_precipitation
    end

    avail_forinfilt = rainfallplusmelt + irsupply_mm
    ustoredepth = sum(sbm.ustorelayerdepth)
    uStorecapacity = sbm.soilwatercapacity - sbm.satwaterdepth - ustoredepth

    runoff_river = min(1.0, sbm.riverfrac) * avail_forinfilt
    runoff_land = min(1.0, sbm.waterfrac) * avail_forinfilt
    avail_forinfilt = max(avail_forinfilt - runoff_river - runoff_land, 0.0)

    rootingdepth = min(sbm.soilthickness * 0.99, sbm.rootingdepth)

    ae_openw_r = min(wl_river * 1000.0 * sbm.riverfrac, sbm.riverfrac * pottrans_soil)
    ae_openw_l = min(wl_land * 1000.0 * sbm.waterfrac, sbm.waterfrac * pottrans_soil)

    restevap = pottrans_soil - ae_openw_r - ae_openw_l

    ae_pond = 0.0
    if nrpaddyirri > 0
        ae_pond = min(sbm.pondingdepth, restevap)
        PondingDepth = sbm.PondingDepth - ActEvapPond
        restevap = restevap - ae_pond
    end

    # evap available for soil evaporation and transpiration
    potsoilevap = restevap * canopygapfraction
    pottrans = restevap * (1 - canopygapfraction)

    # Calculate the initial capacity of the unsaturated store
    ustorecapacity = sbm.soilwatercapacity - sbm.satwaterdepth - ustoredepth

    # Calculate the infiltration flux into the soil column
    infiltsoilpath, infiltsoil, infiltpath, soilinf, pathinf, infiltexcess = infiltration(
        avail_forinfilt,
        sbm.pathfrac,
        sbm.cf_soil,
        tsoil,
        sbm.infiltcapsoil,
        sbm.infiltcappath,
        ustorecapacity,
        modelsnow,
        soilinfreduction,
    )

    usl = set_layerthickness(sbm.zi, sbm.sumlayers)
    z = cumsum(usl)
    n_usl = length(usl)

    usld = copy(sbm.ustorelayerdepth)
    # Using the surface infiltration rate, calculate the flow rate between the
    # different soil layers that contain unsaturated storage assuming gravity
    # based flow only, estimate the gravity based flux rate to the saturated zone
    # (ast) and the updated unsaturated storage for each soil layer.
    if transfermethod == 1 && sbm.maxlayers == 1
        ustorelayerdepth = sbm.ustorelayerdepth[1] + infiltsoilpath
        kv_z = sbm.kvfrac[1] * sbm.kv * exp(-sbm.f * sbm.zi)
        ustorelayerdepth, ast = unsatzone_flow_sbm(
            ustorelayerdepth,
            sbm.soilwatercapacity,
            sbm.satwaterdepth,
            kv_z,
            sbm.usl[1],
            sbm.θₛ,
            sbm.θᵣ,
        )
        usld = setindex(usld, ustorelayerdepth, m)
    else
        for m = 1:n_usl
            l_sat = usl[m] * (sbm.θₛ - sbm.θᵣ)
            kv_z = sbm.kvfrac[m] * sbm.kv * exp(-sbm.f * z[m])
            ustorelayerdepth = m == 1 ? sbm.ustorelayerdepth[m] + infiltsoilpath :
                sbm.ustorelayerdepth[m] + ast
            ustorelayerdepth, ast = unsatzone_flow_layer(
                ustorelayerdepth,
                kv_z,
                l_sat,
                sbm.c[m],
            )
            usld = setindex(usld, ustorelayerdepth, m)
        end
    end

    transfer = ast

    # then evapotranspiration from layers

    # Calculate saturation deficity
    saturationdeficit = sbm.soilwatercapacity - sbm.satwaterdepth

    # First calculate the evaporation of unsaturated storage into the
    # atmosphere from the upper layer.
    if sbm.maxlayers == 1
        soilevapunsat = potsoilevap * min(1.0, saturationdeficit / sbm.soilwatercapacity)
    else
        #In case only the most upper soil layer contains unsaturated storage
        if n_usl == 1
            # Check if groundwater level lies below the surface
            soilevapunsat =
                sbm.zi > 0 ? potsoilevap * min(1.0, usld[k] / (sbm.zi * (sbm.θₛ - sbm.θᵣ))) :
                0.0
        else
            # In case first layer contains no saturated storage
            soilevapunsat = potsoilevap * min(1.0, usld[1] / (usld[1] * ((sbm.θₛ - sbm.θᵣ))))
        end
    end
    # Ensure that the unsaturated evaporation rate does not exceed the
    # available unsaturated moisture
    soilevapunsat = min(soilevapunsat, usld[1])
    # Update the additional atmospheric demand
    potsoilevap = potsoilevap - soilevapunsat
    usld = setindex(usld, usld[1] - soilevapunsat, 1)

    if sbm.maxlayers == 1
        soilevapsat = 0.0
    else
        if n_usl == 1
            soilevapsat = potsoilevap * min(1.0, (usl[1] - sbm.zi) / usl[k])
            soilevapsat = min(soilevapsat, (usl[1] - sbm.zi) * (sbm.θₛ - sbm.θᵣ))
        else
            soilevapsat = 0.0
        end
    end
    soilevap = soilevapunsat + soilevapsat
    satwaterdepth = sbm.satwaterdepth - soilevapsat

    # transpiration from saturated store
    wetroots = scurve(sbm.zi, a = rootingdepth, c = sbm.rootdistpar)
    actevapsat = min(pottrans * wetroots, satwaterdepth)
    satwaterdepth = satwaterdepth - actevapsat
    restpottrans = pottrans - actevapsat

    # actual transpiration from ustore
    actevapustore = 0.0
    for k = 1:n_usl
        ustorelayerdepth, actevapustore, restpottrans = acttransp_unsat_sbm(
            rootingdepth,
            usld[k],
            sbm.sumlayers[k],
            restpottrans,
            actevapustore,
            sbm.c[k],
            usl[k],
            sbm.θₛ,
            sbm.θᵣ,
            sbm.hb,
            ust,
        )
        usld = setindex(usld, ustorelayerdepth, k)
    end

    #check soil moisture balance per layer
    du = 0.0
    for k = n_usl:-1:1
        du = max(0, usld[k] - usl[k] * (sbm.θₛ - sbm.θᵣ))
        usld = setindex(usld, usld[k] - du, k)
        if k > 1
            usld = setindex(usld, usld[k-1] + du, k - 1)
        end
    end

    actinfilt = infiltsoilpath - du
    excesswater = avail_forinfilt - infiltsoilpath - infiltexcess + du

    # Separation between compacted and non compacted areas (correction with the satflow du)
    # This is required for D-Emission/Delwaq
    if infiltsoil + infiltpath > 0.0
        actinfiltsoil = infiltsoil - du * infiltsoil / (infiltpath + infiltsoil)
        actinfiltpath = infiltpath - du * infiltpath / (infiltpath + infiltsoil)
    else
        actinfiltsoil = 0.0
        actinfiltpath = 0.0
    end
    excesswatersoil = max(soilinf - actinfiltsoil, 0.0)
    excesswaterpath = max(pathinf - actinfiltpath, 0.0)

    ksat = sbm.kvfrac[n_usl] * sbm.kv * exp(-sbm.f * sbm.zi)
    ustorecapacity = sbm.soilwatercapacity - sbm.satwaterdepth - sum(usld)
    maxcapflux = max(0.0, min(ksat, actevapustore, ustorecapacity, sbm.satwaterdepth))

    if sbm.zi > rootingdepth
        capfluxscale =
            sbm.capscale / (sbm.capscale + sbm.zi - rootingdepth) * Δt /
            basetimestep
    else
        capfluxscale = 0.0
    end
    capflux = maxcapflux * capfluxscale

    netcapflux = capflux
    actcapflux = 0.0
    for k = n_usl:-1:1
        toadd = min(netcapflux, max(usl[k] * (sbm.θₛ - sbm.θᵣ) - usld[k], 0.0))
        usld = setindex(usld, usld[k] + toadd, k)
        netcapflux = netcapflux - toadd
        actcapflux = actcapflux + toadd
    end

    deepksat = sbm.kv * exp(-sbm.f * sbm.soilthickness)
    deeptransfer = min(sbm.satwaterdepth, deepksat)
    actleakage = max(0.0, min(sbm.maxleakage, deeptransfer))

    # recharge (mm) for saturated zone, multiply by 1000 * DW (flowlength) for
    # ssf kinematic wave
    recharge = (transfer - actcapflux - actleakage - actevapsat - soilevapsat)
    transpiration = actevapsat + actevapustore
    actevap = soilevap + transpiration + ae_openw_r + ae_openw_l + ae_pond



    return SBM{Float64,sbm.nlayers,sbm.nlayers + 1}(
        maxlayers = sbm.maxlayers,
        nlayers = sbm.nlayers,
        riverfrac = sbm.riverfrac,
        cfmax = sbm.cfmax,
        tt = sbm.tt,
        tti = sbm.tti,
        ttm = sbm.ttm,
        whc = sbm.whc,
        w_soil = sbm.w_soil,
        cf_soil = sbm.cf_soil,
        θₛ = sbm.θₛ,
        θᵣ = sbm.θᵣ,
        kv = sbm.kv,
        kvfrac = sbm.kvfrac,
        m = sbm.m,
        hb = sbm.hb,
        soilthickness = sbm.soilthickness,
        act_thickl = sbm.act_thickl,
        sumlayers = sbm.sumlayers,
        infiltcappath = sbm.infiltcappath,
        infiltcapsoil = sbm.infiltcapsoil,
        maxleakage = sbm.maxleakage,
        waterfrac = sbm.waterfrac,
        pathfrac = sbm.pathfrac,
        altitude = sbm.altitude,
        rootingdepth = sbm.rootingdepth,
        rootdistpar = sbm.rootdistpar,
        capscale = sbm.capscale,
        et_reftopot = sbm.et_reftopot,
        sl = sbm.sl,
        swood = sbm.swood,
        kext = sbm.kext,
        c = sbm.c,
        e_r = sbm.e_r,
        cmax = cmax,
        canopygapfraction = canopygapfraction,
        lai = lai,
        canopystorage = canopystorage,
        snow = snow,
        snowwater = snowwater,
        tsoil = tsoil,
        actinfilt = actinfilt,
        recharge = recharge,
        transpiration = transpiration,
        soilevap = soilevap,
        interception = interception,
        ae_openw_r = ae_openw_r,
        ae_openw_l = ae_openw_l,
        actevapsat = actevapsat,
        actevap = actevap,
        ustorelayerdepth = usld,
        transfer = transfer,
        satwaterdepth = satwaterdepth,
        actinfiltsoil = actinfiltsoil,
        actinfiltpath = actinfiltpath,
        excesswater = excesswater,
        excesswatersoil = excesswatersoil,
        excesswaterpath = excesswaterpath,
    )
end
