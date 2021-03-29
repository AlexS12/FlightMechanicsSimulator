function f(x, p, t)
    mass = p[1]
    xcg = p[2]
    controls = p[3]
    atmosphere = p[4]
    gravity=p[5]

    controls_arr = get_value.(controls, t)

    x_dot, outputs = f(time, x, mass, xcg, controls_arr, atmosphere, gravity)

    return x_dot
end


function f(time, x, mass, xcg, controls, atmosphere, gravity)

    # C     x(1)  -> vt (m/s)
    # C     x(2)  -> α (rad)
    # C     x(3)  -> β (rad)
    # C     x(4)  -> ϕ (rad)
    # C     x(5)  -> θ (rad)
    # C     x(6)  -> ψ (rad)
    # C     x(7)  -> p (rad/s)
    # C     x(8)  -> q (rad/s)
    # C     x(9)  -> r (rad/s)
    # C     x(10) -> North (m)
    # C     x(11) -> East (m)
    # C     x(12) -> Altitude (m)
    # C     x(13) -> pow

    # Assign state
    vt = x[1]
    α = x[2] * RAD2DEG
    β = x[3] * RAD2DEG
    ϕ = x[4]
    θ = x[5]
    ψ = x[6]
    p = x[7]
    q = x[8]
    r = x[9]
    height = x[12]
    pow = x[13]

    atmosphere = atmosphere(height)
    T = get_temperature(atmosphere)
    ρ = get_density(atmosphere)
    a = get_sound_velocity(atmosphere)
    p = get_pressure(atmosphere)

    # Air data computer
    amach, qbar = adc(vt, T, ρ, a, p)

    # Update mass, inertia and CG
    inertia = [
        AXX 0.0 AXZ;
        0.0 AYY 0.0;
        AXZ 0.0 AZZ
    ]  # Kg·m²

    # Calculate forces and moments
    # Propulsion
    Tx, Ty, Tz, LT, MT, NT = calculate_prop_forces_moments(x, amach, controls)
    h = calculate_prop_gyro_effects()
    # Aerodynamics
    Fax, Fay, Faz, La, Ma, Na = calculate_aero_forces_moments(x, controls, xcg, qbar, S, B, CBAR)
    # Gravity
    Fgx, Fgy, Fgz = get_gravity_body(gravity, θ, ϕ) .* mass

    # Total forces & moments
    Fx = Fgx + Fax + Tx
    Fy = Fgy + Fay + Ty
    Fz = Fgz + Faz + Tz

    L = La
    M = Ma
    N = Na

    forces = [Fx, Fy, Fz]
    moments = [L, M, N]

    x_dot = sixdof_aero_earth_euler_fixed_mass(time, x, mass, inertia, forces, moments, h)

    # Engine dynamic model
    thtl = controls[1]
    pdot = calculate_pdot(thtl, pow)

    x_dot = [x_dot..., pdot]

    # Outputs
    gravity_down = get_gravity_accel(gravity)
    outputs = calculate_outputs(x, amach, qbar, S, mass, gravity_down, [Fax, Fay, Faz], [Tx, Ty, Tz])

    return x_dot, outputs

end


function calculate_outputs(x, amach, qbar, S, mass, g, Fa, Fp)

    outputs = Array{Float64}(undef, 7)

    # vt = x[1]
    α = x[2] * RAD2DEG
    # β = x[3] * RAD2DEG
    # ϕ = x[4]
    # θ = x[5]
    # ψ = x[6]
    # p = x[7]
    q = x[8]
    # r = x[9]
    # height = x[12]
    # pow = x[13]

    Fax, Fay, Faz = Fa
    Tx, Ty, Tz = Fp

    qbarS = qbar * S

    rmqs = qbarS / mass

    ax = (Fax + Tx) / mass
    ay = (Fay + Ty) / mass
    az = (Faz + Tz) / mass

    along = ax / g
    an = -az / g
    alat = ay / g

    outputs[1] = an
    outputs[2] = alat
    outputs[3] = along
    outputs[4] = qbar
    outputs[5] = amach
    outputs[6] = q
    outputs[7] = α

    return outputs
end
