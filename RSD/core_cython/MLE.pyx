cimport cython

import numpy as np
cimport numpy as np

from libc.math cimport abs, sqrt, log, M_PI, INFINITY

# Import math functions to work with complex numbers
cdef extern from "complex.h":
    np.complex128_t csqrt(np.complex128_t)
    np.complex128_t ccos(np.complex128_t)
    np.complex128_t cacos(np.complex128_t)
    np.complex128_t cpow(np.complex128_t, np.complex128_t)


@cython.cdivision(True)
cdef (np.complex128_t, np.complex128_t) solve_quadratic_equation(
    np.complex128_t a0,
    np.complex128_t b0,
    np.complex128_t c0
):
    '''
    Solve the quadratic equation
    a0*x^2 + b0*x + c0
    '''
    # a0 -> 1
    cdef np.complex128_t a = b0 / a0
    cdef np.complex128_t b = c0 / a0

    a0 = -0.5*a
    cdef np.complex128_t delta = a0*a0 - b
    cdef np.complex128_t sqrt_delta = csqrt(delta)

    return (a0 - sqrt_delta, a0 + sqrt_delta)


@cython.cdivision(True)
cdef np.complex128_t signed_cubic_root(np.complex128_t x):
    '''
    Find cubic root of x with correct sign
    '''
    if x.real >= 0:
        return cpow(x, 1.0 / 3.0)
    else:
        return -cpow(-x, 1.0 / 3.0)


@cython.cdivision(True)
cdef np.complex128_t cubic_equation_real_root(
    np.complex128_t a0,
    np.complex128_t b0,
    np.complex128_t c0,
    np.complex128_t d0
):
    '''
    Find real root of the cubic equation
    a0*x^3 + b0*x^2 + c0*x + d0
    '''
    # a0 -> 1
    cdef np.complex128_t a = b0 / a0
    cdef np.complex128_t b = c0 / a0
    cdef np.complex128_t c = d0 / a0

    cdef np.complex128_t a13 = a / 3.0
    cdef np.complex128_t a2 = a13*a13
    cdef np.complex128_t f = b / 3.0 - a2
    cdef np.complex128_t g = a13 * (2*a2 - b) + c
    cdef np.complex128_t h = 0.25*g*g + f*f*f
    
    cdef np.complex128_t j, k, m, sqrt_h
    if f == g and g == h and h == 0:
        return -signed_cubic_root(c)
    elif h.real <= 0:
        j = csqrt(-f)
        k = cacos(-0.5*g / (j*j*j))
        m = ccos(k / 3.0)
        return 2*j*m - a13
    else:
        sqrt_h = csqrt(h)
        return signed_cubic_root(-0.5*g + sqrt_h) + signed_cubic_root(-0.5*g - sqrt_h) - a13


@cython.cdivision(True)
cdef (np.complex128_t, np.complex128_t, np.complex128_t, np.complex128_t) solve_quartic_equation(
    np.complex128_t a0, 
    np.complex128_t b0, 
    np.complex128_t c0, 
    np.complex128_t d0,
    np.complex128_t e0
):
    '''
    Solve the quartic equation 
    a0*x^4 + b0*x^3 + c0*x^2 + d0*x + e0
    '''
    # a0 -> 1
    cdef np.complex128_t a = b0 / a0
    cdef np.complex128_t b = c0 / a0
    cdef np.complex128_t c = d0 / a0
    cdef np.complex128_t d = e0 / a0

    # Some repeating variables
    a0 = 0.25*a
    cdef np.complex128_t a02 = a0*a0

    # Coefficients of subsidiary cubic euqtion
    cdef np.complex128_t p = 3*a02 - 0.5*b
    cdef np.complex128_t q = a*a02 - b*a0 + 0.5*c
    cdef np.complex128_t r = 3*a02*a02 - b*a02 + c*a0 - d

    # One root of the cubic equation
    cdef np.complex128_t z0 = cubic_equation_real_root(1, p, r, p*r - 0.5*q*q)

    # Additional variables
    cdef np.complex128_t s = csqrt(2*p + 2*z0.real)
    cdef np.complex128_t t
    if s == 0:
        t = z0*z0 + r
    else:
        t = -q / s

    # Compute roots of quadratic equations
    cdef np.complex128_t r0, r1, r2, r3
    
    r0, r1 = solve_quadratic_equation(1, s, z0 + t)
    r2, r3 = solve_quadratic_equation(1, -s, z0 - t)
    
    return (r0 - a0, r1 - a0, r2 - a0, r3 - a0)


@cython.cdivision(True)
cdef (np.float64_t, np.float64_t, np.float64_t, np.float64_t) optimize_NLL_on_segment(
    np.float64_t r_sum, np.float64_t r_l, np.float64_t r_h,
    np.float64_t x_l, np.float64_t x_h,
    np.float64_t x_sq_l, np.float64_t x_sq_h,
    np.float64_t l_cur, np.float64_t l_next,
    long int iternum
):
    '''
    Minimize negative log-likelihood on a given segment
    '''
    cdef np.float64_t a = 1 / r_l + 1 / r_h
    cdef np.float64_t b = x_h / r_h - x_l / r_l
    cdef np.float64_t c = x_sq_l + x_sq_h - x_l**2 / r_l - x_h**2 / r_h
    
    # TODO: think about this!
    # a1 = r_l * r_h * a
    #cdef np.float64_t a1 = r_l + r_h
    # b1 = (r_l * r_h)**2 * b
    #cdef np.float64_t b1 = r_l*r_h * (r_l*x_h - r_h*x_l)
    # c1 = r_l * r_h * c
    #cdef np.float64_t c1 = r_l * (r_h * x_sq_h - x_h**2) + r_h * (r_l * x_sq_l - x_l**2)
    #r0, r1, r2, r3 = solve_quartic_equation(r_sum * a1**2, -2 * M_PI * b1, 2 * c1 * (r_sum * a1 - M_PI*r_l*r_h), 0, r_sum * c1**2)

    cdef np.float64_t t_cur = r_l * l_cur - x_l
    cdef np.float64_t t_next = r_l * l_next - x_l

    cdef np.complex128_t r0, r1, r2, r3
    r0, r1, r2, r3 = solve_quartic_equation(r_sum * a**2, -2 * M_PI * b, 2 * c * (r_sum * a - M_PI), 0, r_sum * c**2)
    
    cdef np.complex128_t critical_t[6]
    # Boundary + roots of the derivative
    critical_t[:] = [t_cur, t_next, r0, r1, r2, r3]
    
    cdef int i = 0
    # Temporary variables
    cdef np.float64_t t, s, NLL
    # Local minimum variables
    cdef np.float64_t t_loc_min, s_loc_min, NLL_loc_min
    NLL_loc_min = INFINITY
    for i in range(6):
        # We do not want complex roots
        if abs(critical_t[i].imag) > 1e-8:
            continue

        t = critical_t[i].real
        # Roots should lie within [t_cur, t_next] interval
        if t < t_cur or t > t_next:
            continue
        
        if iternum == 0 and i == 0:
            s = 0
            NLL = r_sum * log(b)
        else:
            s = cubic_equation_real_root(
                sqrt(2*M_PI) * r_sum, 
                0, 
                -sqrt(2*M_PI) * (a*t**2  + c),
                (a*t - b) * (a*t**2 + c)
            ).real

            if s < 0:
                NLL = INFINITY
            else:
                if s < 1e-6:
                    s = 1e-6
                NLL = r_sum * log(sqrt(2*M_PI) * s - a*t + b) + (a * t**2 + c) / (2 * s**2)

        if NLL < NLL_loc_min:
            t_loc_min = t
            s_loc_min = s
            NLL_loc_min = NLL

    cdef np.float64_t l_loc_min = (t_loc_min + x_l) / r_l
    cdef np.float64_t h_loc_min = (x_l + x_h - r_l * l_loc_min) / r_h
    if l_loc_min == -8.285968798588563 and h_loc_min == -9.930992198979034:
        print("##########################")
        print(t_loc_min, s_loc_min)
        print(sqrt(2*M_PI) * s_loc_min)
        print(a * t_loc_min)
        print(b)
        print(sqrt(2*M_PI) * s_loc_min - a*t_loc_min + b)
        print("##########################")
       

    return (l_loc_min, h_loc_min, s_loc_min, NLL_loc_min)

    
@cython.cdivision(True)
@cython.boundscheck(False)
@cython.wraparound(False)
def minimize_NLL(
        np.ndarray[np.float64_t, ndim=1] data, 
        np.ndarray[np.float64_t, ndim=1] weights
    ):
    '''
    Fast minimization of RSD negative log-likelihood.
    Briefly:
        - Traverse the polygonal chain containing the global minimum;
        - Find local minimum on each segment of the chain;
        - Take the global minimum.
    Note: input data vector should be already sorted (ascending).
    '''
    # Total number of points
    cdef long int N = data.shape[0]
    # Summary weight
    cdef np.float64_t r_sum = np.sum(weights)
    
    # Region indexers (u is a number of l axis, v is a number of h axis)
    cdef long int u = 0
    cdef long int v = N - 1
    # Global counter
    cdef long int i = 0
    
    # Coordinates of current segment's left-top point
    cdef np.float64_t l_cur = data[0]
    cdef np.float64_t h_cur = data[0]
    # Coordinates of current segment's bottom-right point (or left-top coordinates for the next segment)
    cdef np.float64_t l_next
    cdef np.float64_t h_next
    
    # Sum of weights for l and h
    cdef np.float64_t r_l = weights[0]
    cdef np.float64_t r_h = weights[N - 1]
    
    # Weighted sum of x's for l and h
    cdef np.float64_t x_l = weights[0] * data[0]
    cdef np.float64_t x_h = weights[N - 1] * data[N - 1]
    
    # Weighted sum of x squares for l and h
    cdef np.float64_t x_sq_l = weights[0] * data[0]**2
    cdef np.float64_t x_sq_h = weights[N - 1] * data[N - 1]**2
    
    # Local minimums
    cdef np.float64_t l_loc_min, h_loc_min, s_loc_min, NLL_loc_min
    # Global minimums
    cdef np.float64_t l_glob_min, h_glob_min, s_glob_min, NLL_glob_min
    NLL_glob_min = INFINITY
    
    # Traverse extremal chain from l = min(data), h = max(data) to l = h
    while v - u >= 1:
        # First, determine coordinates l_next and h_next
        if v - u > 1:
            l_next = min(data[u + 1], (x_l + x_h - r_h * data[v - 1]) / r_l)
            h_next = max(data[v - 1], (x_l + x_h - r_l * data[u + 1]) / r_h)
        else:
            l_next = (x_l + x_h) / (r_l + r_h)
            h_next = l_next
        
        # Then, find local minimum on current segment
        l_loc_min, h_loc_min, s_loc_min, NLL_loc_min = optimize_NLL_on_segment(
            r_sum, r_l, r_h,
            x_l, x_h,
            x_sq_l, x_sq_h,
            l_cur, l_next,
            i
        )
        # Compare with current global minimum
        if NLL_loc_min < NLL_glob_min:
            l_glob_min = l_loc_min
            h_glob_min = h_loc_min
            s_glob_min = s_loc_min
            NLL_glob_min = NLL_loc_min
        
        # Finally, move to the next segment
        if l_next == data[u + 1]:
            r_l += weights[u + 1]
            x_l += weights[u + 1] * data[u + 1]
            x_sq_l += weights[u + 1] * data[u + 1]**2
            u += 1
        else:
            r_h += weights[v - 1]
            x_h += weights[v - 1] * data[v - 1]
            x_sq_h += weights[v - 1] * data[v - 1]**2
            v -= 1

        l_cur, h_cur = l_next, h_next
        i += 1

    return (l_glob_min, h_glob_min, s_glob_min, NLL_glob_min)
