module bc09
    use constants_def, only: dp
    
    ! data structure for the parameter arrays
    ! moments of the composition
    integer, parameter :: icomp_A = 1
    integer, parameter :: icomp_Z = icomp_A + 1
    integer, parameter :: icomp_Z53 = icomp_Z + 1
    integer, parameter :: icomp_Z2 = icomp_Z53 + 1
    integer, parameter :: icomp_Z73 = icomp_Z2 + 1
    integer, parameter :: icomp_Z52 = icomp_Z73 + 1
    integer, parameter :: icomp_ZZ1_32 = icomp_Z52 + 1
    integer, parameter :: icomp_Z2XoA2 = icomp_ZZ1_32 + 1
    integer, parameter :: icomp_Ye = icomp_Z2XoA2 + 1
    integer, parameter :: icomp_Yn = icomp_Ye + 1
    integer, parameter :: icomp_Q = icomp_Yn + 1
    integer, parameter :: number_comp_rpar = icomp_Q
        
    integer, parameter :: igrav = number_comp_rpar + 1
    integer, parameter :: itau = igrav + 1
    integer, parameter :: iTeff = itau + 1
    integer, parameter :: itemp = iTeff + 1
    integer, parameter :: ipres = itemp + 1
    integer, parameter :: irho = ipres + 1
    integer, parameter :: iKph = irho + 1
    integer, parameter :: iChi_rho = iKph + 1
    integer, parameter :: iChi_T = iChi_rho + 1
    integer, parameter :: idel_ad = iChi_T + 1
    integer, parameter :: number_base_rpar = idel_ad
    ! further storage can be tacked on at end of rpar for Yion's
    
    integer, parameter :: ihandle = 1
    integer, parameter :: iNcharged = ihandle + 1
    integer, parameter :: number_base_ipar = iNcharged
    ! further storage can be tacked on at end of ipar for charged id's
    
    ! error codes
    integer, parameter :: negative_photosphere_gas_pressure = -2
    integer, parameter :: negative_photosphere_density = -3
    integer, parameter :: bad_composition = -4
    
    ! defaults for integration
    real(dp), parameter :: default_lnTeff_min = 5.0
    real(dp), parameter :: default_lnTeff_max = 6.7
    
contains
    
	subroutine do_get_bc09_Teff(grav, Plight, Tb, Teff, flux, ierr, Teff_min, Teff_max)
		use constants_def
		real(dp), intent(in) :: grav	! surface gravity, in the local frame
		real(dp), intent(in) :: Plight	! pressure at which layer of light elements terminates
		real(dp), intent(in), dimension(:) :: Tb	! temperature at a base column
		real(dp), intent(out), dimension(:) :: Teff, flux	! effective temperature and flux
        integer, intent(out) :: ierr
        real(dp), intent(in), optional :: Teff_min, Teff_max ! limits for boundaries of dense table
        integer ::  size_tab ! = 4*size(Tb)
        real(dp), dimension(:), allocatable :: tabTb9, tabTeff, tabTeff6_4
        real(dp) :: lnTeff_min, lnTeff_max
        integer :: i
        
        ! make a very dense table of Tb(Teff); then interpolate to get Teff(Tb)
        size_tab = 4*size(Tb)
        allocate(tabTb9(size_tab),tabTeff(size_tab),tabTeff6_4(size_tab))

        ! would make sense to check that runs with the minimum and maximum Teff on the dense table
        ! actually encompass the desired range of Tb
        if (present(Teff_min)) then
            lnTeff_min = log(Teff_min)
        else
            lnTeff_min = default_lnTeff_min
        end if
        if (present(Teff_max)) then
            lnTeff_max = log(Teff_max)
        else
            lnTeff_max = default_lnTeff_max
        end if
        
!         tau = ?
!         Teff = ?
        ! compute dense table
        do i = 1, size_tab
            ! get Pph(Teff)
!            call find_photospheric_pressure(Teff,grav,tau,Pphoto,eos_handle,ierr) 
!		write(*,*) tabTeff_4(i), Pphoto           
        end do
        
        ! interpolate from dense table to get finished product
        
        deallocate(tabTb9,tabTeff6_4)
    end subroutine do_get_bc09_Teff
    
    subroutine do_integrate_bc09_atm(grav,lgyb,lgy_light,lgTeff,lgTb,eos_handle,ierr,rho,P,kappa)
        use iso_fortran_env, only: error_unit
        use constants_def
        use nucchem_def
        use nucchem_lib
        real(dp), intent(in) :: grav    ! cm/s**2
        real(dp), intent(in) :: lgyb    ! log_10(g/cm**2); base of atmosphere
        real(dp), intent(in) :: lgy_light   ! log_10(g/cm**2); light/heavy transition
        real(dp), intent(in) :: lgTeff  ! log_10(K)
        real(dp), intent(out) :: lgTb   ! log_10(K)
        integer, intent(in) :: eos_handle
        integer, intent(out) :: ierr
        real(dp), intent(inout) :: rho  ! set < 0 to compute a guess
        real(dp), intent(out) :: P, kappa ! for testing
        ! composition
        integer, parameter :: number_species = 2
        integer, dimension(number_species) :: charged_ids, chem_ids
        real(dp), dimension(number_species) :: Y, Yion
        real(dp) :: Xsum
        integer :: ncharged
        ! data arrays
        integer :: lrpar, lipar
        integer, pointer :: ipar(:) => null() ! (lipar)
        real(dp), pointer :: rpar(:) => null()  ! (lrpar)
        real(dp) :: Teff, tau!, rho, P, kappa
        type(composition_info_type) :: ionic
        real(dp) :: lnP, lnT4(1), dlnT4dlnP(1), h
        
        ierr = 0
        ! composition is a He/Fe mix
        chem_ids = [ get_nuclide_index('he4'), get_nuclide_index('fe56') ]
        if (any(chem_ids == nuclide_not_found)) then    ! this is a fatal error
            ierr = nuclide_not_found
            return
        endif
        
        ! set size of data structure        
        lrpar = number_base_rpar + number_species
        lipar = number_base_ipar + number_species
        allocate(ipar(lipar), rpar(lrpar))
        
        Teff = 10.0**lgTeff
        tau = twothird
        
        ! set photosphere to be pure He and compute moments
        Y = [1.0_dp, 0.0_dp]/nuclib% A(chem_ids)
        call compute_composition_moments(number_species,chem_ids,Y,ionic,Xsum, &
        &   ncharged, charged_ids, Yion, exclude_neutrons = .TRUE.)

        ! sanity check on composition
        if (Xsum - 1.0_dp > 2.0*epsilon(1.0_dp)) then
            ierr = bad_composition
            return
        end if
        
        ! stuff the parameter vectors
        rpar(icomp_A) = ionic% A
        rpar(icomp_Z) = ionic% Z
        rpar(icomp_Z53) = ionic% Z53
        rpar(icomp_Z2) = ionic% Z2
        rpar(icomp_Z73) = ionic% Z73
        rpar(icomp_Z52) = ionic% Z52
        rpar(icomp_ZZ1_32) = ionic% ZZ1_32
        rpar(icomp_Z2XoA2) = ionic% Z2XoA2
        rpar(icomp_Ye) = ionic% Ye
        rpar(icomp_Yn) = ionic% Yn
        rpar(icomp_Q) = ionic% Q
        rpar(igrav) = grav
        rpar(itau) = tau
        rpar(iTeff) = Teff
        rpar(number_base_rpar + 1:number_base_rpar+ncharged) = Yion(:)
        
        ipar(ihandle) = eos_handle
        ipar(iNcharged) = ncharged
        ipar(number_base_ipar+1:number_base_ipar+ncharged) = charged_ids

        print *,'finding photosphere, rho guess = ',rho
        call find_photospheric_pressure(Teff,grav,tau,rho,P,kappa, &
            &   lrpar, rpar, lipar, ipar, ierr)
        print *,'rho, P, K = ',rho,P,kappa
        if (ierr /= 0) return
        ! start the integration
        rpar(irho) = rho
        lnP = log(P)
        lnT4(1) = 0.0
        h = 0.1_dp
        call deriv(1, lnP, h, lnT4, dlnT4dlnP, lrpar, rpar, lipar, ipar, ierr)
        print *,'dlnT4/dlnP = ',dlnT4dlnP(1)
        deallocate(ipar, rpar)
        
    end subroutine do_integrate_bc09_atm
      
    subroutine find_photospheric_pressure(Teff,grav,tau,rho_ph,P_ph,kappa, &
        &   lrpar,rpar,lipar,ipar,ierr)
        use iso_fortran_env, only: error_unit
        use constants_def
        use nucchem_def
    	use nucchem_lib
    	use num_lib
        integer, parameter :: default_maximum_iterations_photosphere = 20
        real(dp), parameter :: default_tolerance_photosphere_lnrho = 1.0e-6_dp
        real(dp), parameter :: default_tolerance_photosphere_condition = 1.0e-8_dp
        real(dp), intent(in) :: Teff    ! K
        real(dp), intent(in) :: grav    ! cm/s**2
        real(dp), intent(in) :: tau     ! may need to adjust to something other than 2.0/3.0, 
            ! especially at higher temperatures
        real(dp), intent(inout) :: rho_ph   ! on input set <= 0 to have routine generate guess; on 
        !   output, it contains the value of the photospheric density
        real(dp), intent(out) :: P_ph   ! photospheric pressure, cgs units
        real(dp), intent(out) :: kappa  ! opacity at photosphere
        integer, intent(in) :: lrpar, lipar
        integer, intent(inout), pointer :: ipar(:) ! (lipar)
        real(dp), intent(inout), pointer :: rpar(:) ! (lrpar)
        integer, intent(out) :: ierr
        real(dp) :: lnrho_ph,lnrho
        integer :: i, maximum_iterations
        real(dp) :: sigma_Th
        real(dp) :: lnrho_guess, kappa_Th, Pgas, fallback_Pphoto
        real(dp) :: lnrho1, lnrho3, dlnrho, ph1, ph3, eps_lnrho, eps_ph
        
        ierr = 0

     	! set iteration count, tolerances
        maximum_iterations = default_maximum_iterations_photosphere
        eps_lnrho = default_tolerance_photosphere_lnrho
        eps_ph = default_tolerance_photosphere_condition
        fallback_Pphoto = 2.0_dp*onethird*arad*Teff**4

        ! scale tolerance to a thomson scaterring atmosphere
        sigma_Th = 8.0_dp*onethird*pi*(electroncharge**2/Melectron/clight2)**2
        kappa_Th = sigma_Th*avogadro*rpar(icomp_Ye)
        eps_ph = default_tolerance_photosphere_condition*tau*grav/kappa_Th
        
        ! use initial guess with ideal gas pressure and thomson scattering
        if (rho_ph < 0.0_dp) then
            Pgas = tau*grav/kappa_Th - onethird*arad*Teff**4
            if (Pgas < 0.0_dp) then
                ierr = negative_photosphere_gas_pressure
                P_ph = fallback_Pphoto
                kappa = kappa_Th
                return
            end if
            lnrho_guess = log(Pgas*amu*rpar(icomp_A)/(rpar(icomp_Z)+1.0)/boltzmann/Teff)
        else
            lnrho_guess = log(rho_ph)
        end if
        
        ! get brackets for root find
        dlnrho = 0.1_dp
        call look_for_brackets(lnrho_guess, dlnrho, lnrho1, lnrho3, photosphere, ph1, ph3, &
             & maximum_iterations, lrpar, rpar, lipar, ipar, ierr)
        if (ierr /= 0) then
            write(error_unit,*) 'unable to bracket root: ierr = ', ierr
            P_ph = fallback_Pphoto
            rho_ph = exp(lnrho_guess)
            kappa = rpar(iKph)
            return
        end if

		lnrho_ph = safe_root_with_initial_guess(photosphere,lnrho_guess,lnrho1,lnrho3,ph1,ph3, &
            &   maximum_iterations,eps_lnrho,eps_ph,lrpar,rpar,lipar,ipar,ierr)

        if (ierr /= 0) then
            write(error_unit,*) 'unable to converge on photospheric density: ',lnrho_guess,lnrho_ph
            P_ph = fallback_Pphoto
            rho_ph = exp(lnrho_guess)
            kappa = rpar(iKph)
            return
        end if
        P_ph = rpar(ipres)
        rho_ph = exp(lnrho_ph)
        kappa = rpar(iKph)
    end subroutine find_photospheric_pressure    

    real(dp) function photosphere(lnrho, dfdlnrho, lrpar, rpar, lipar, ipar, ierr)
       ! returns with ierr = 0 if was able to evaluate f and df/dx at x
       ! if df/dx not available, it is okay to set it to 0
       use constants_def
       use nucchem_def
       use nucchem_lib
       use dStar_eos_lib
       use conductivity_lib
       
       integer, intent(in) :: lrpar, lipar
       real(dp), intent(in) :: lnrho
       real(dp), intent(out) :: dfdlnrho
       integer, intent(inout), pointer :: ipar(:) ! (lipar)
       real(dp), intent(inout), pointer :: rpar(:) ! (lrpar)
       integer, intent(out) :: ierr
       real(dp) :: rho, gravity, tau_ph, Teff, P, kappa, Gamma, eta, Xsum, chi
       integer :: eos_handle, ncharged, phase
       type(composition_info_type) :: ionic
       type(conductivity_components) :: K
       real(dp), dimension(num_dStar_eos_results) :: res
	   integer, pointer, dimension(:) :: charged_ids=>null()
       real(dp), pointer, dimension(:) :: Yion=>null()
       
       ierr = 0
       
       ! unpack the arguments       
       rho = exp(lnrho)
       
       ionic = composition_info_type(A = rpar(icomp_A), &
       &    Z = rpar(icomp_Z), &
       &    Z53 = rpar(icomp_Z53), &
       &    Z2 = rpar(icomp_Z2), &
       &    Z73 = rpar(icomp_Z73), &
       &    Z52 = rpar(icomp_Z52), &
       &    ZZ1_32 = rpar(icomp_ZZ1_32), &
       &    Z2XoA2 = rpar(icomp_Z2XoA2), &
       &    Ye = rpar(icomp_Ye), &
       &    Yn = rpar(icomp_Yn), &
       &    Q = rpar(icomp_Q) )
       
       gravity = rpar(igrav)
       tau_ph = rpar(itau)
       Teff = rpar(iTeff)
       
       eos_handle = ipar(ihandle)
       ncharged = ipar(iNcharged)
       charged_ids=>ipar(number_base_ipar+1:number_base_ipar+ncharged)
       Yion=>rpar(number_base_rpar+1:number_base_rpar+ncharged)
       chi = use_default_nuclear_size

       call eval_crust_eos(eos_handle,rho,Teff,ionic,ncharged,charged_ids,Yion, &
       		&   res,phase,chi)
       
       P = exp(res(i_lnP))
       rpar(ipres) = P
       eta = res(i_Theta) !1.0/TpT
       Gamma = res(i_Gamma)
       call get_thermal_conductivity(rho,Teff,chi, &
           & Gamma,eta,ionic,K,which_components=cond_exclude_sf) !cond_use_only_kap)
       kappa = 4.0*onethird*arad*clight*Teff**3/rho/K% total
       rpar(iKph) = kappa
	   dfdlnrho = 0.0
       
       photosphere = P - tau_ph*gravity/kappa
    end function photosphere
    
    subroutine deriv(n, lnP, h, lnT4, dlnT4dlnP, lrpar, rpar, lipar, ipar, ierr)
       use constants_def
       use nucchem_def
       use nucchem_lib
       use dStar_eos_lib
       use conductivity_lib

       integer, intent(in) :: n, lrpar, lipar
       real(dp), intent(in) :: lnP, h
       real(dp), intent(inout) :: lnT4(:)
       real(dp), intent(out) :: dlnT4dlnP(:)
       integer, intent(inout), pointer :: ipar(:) ! (lipar)
       real(dp), intent(inout), pointer :: rpar(:) ! (lrpar)
       integer, intent(out) :: ierr ! nonzero means retry with smaller timestep.
       real(dp) :: lnrho_guess, Teff, P, T, lnrho, rho, chi, eta, Gamma, kappa, grav
       integer :: eos_handle, ncharged, phase
       real(dp), dimension(num_dStar_eos_results) :: res
       integer, dimension(:), pointer :: charged_ids=>null()
       real(dp), dimension(:), pointer :: Yion=>null()
       type(composition_info_type) :: ionic
       type(conductivity_components) :: K
       
       ierr = 0

       ! unpack the arguments
       Teff = rpar(iTeff)
       P = exp(lnP)
       T = rpar(iTeff)*exp(0.25*lnT4(1))
       grav = rpar(igrav)
       
       ! store local values
       rpar(ipres) = P
       rpar(itemp) = T

       ! set the composition information from rpar
       ionic = composition_info_type(A = rpar(icomp_A), &
       &    Z = rpar(icomp_Z), &
       &    Z53 = rpar(icomp_Z53), &
       &    Z2 = rpar(icomp_Z2), &
       &    Z73 = rpar(icomp_Z73), &
       &    Z52 = rpar(icomp_Z52), &
       &    ZZ1_32 = rpar(icomp_ZZ1_32), &
       &    Z2XoA2 = rpar(icomp_Z2XoA2), &
       &    Ye = rpar(icomp_Ye), &
       &    Yn = rpar(icomp_Yn), &
       &    Q = rpar(icomp_Q) )
       eos_handle = ipar(ihandle)
       ncharged = ipar(iNcharged)
       charged_ids=>ipar(number_base_ipar+1:number_base_ipar+ncharged)
       Yion=>rpar(number_base_rpar+1:number_base_rpar+ncharged)
       chi = use_default_nuclear_size

       ! find the density
       print *,'derivs; looking for rho with guess',rpar(irho)
       lnrho_guess = log(rpar(irho))
       call get_rho_from_PT(ierr)
       if (ierr /= 0) then
           print *,'error in getting rho'
           return
       end if
       rho = exp(lnrho)
       rpar(irho) = rho

       call eval_crust_eos(eos_handle,rho,Teff,ionic,ncharged,charged_ids,Yion, &
               &   res,phase,chi)
    
       eta = res(i_Theta) !1.0/TpT
       Gamma = res(i_Gamma)
       call get_thermal_conductivity(rho,T,chi, &
           & Gamma,eta,ionic,K,which_components=cond_exclude_sf) !cond_use_only_kap)
       kappa = 4.0*onethird*arad*clight*T**3/rho/K% total
       rpar(iKph) = kappa

       dlnT4dlnP(1) = 0.75_dp*kappa*P/grav/exp(lnT4(1))

    contains
        subroutine get_rho_from_PT(ierr)
            use num_lib, only: safe_root_without_brackets
            integer, intent(out) :: ierr
            real(dp) :: dlnrho  ! increment for searching for brackets
            real(dp) :: epsx, epsy
            integer :: imax, max_newt
            
            ierr = 0
            max_newt = 20
            imax = 60
            epsx = 1.0e-6_dp
            epsy = 1.0e-6_dp
            lnrho = safe_root_without_brackets(eval_pressure,lnrho_guess,dlnrho,max_newt, &
            &   imax, epsx,epsy,lrpar,rpar,lipar,ipar,ierr)
        end subroutine get_rho_from_PT

    end subroutine deriv

    real(dp) function eval_pressure(lnrho, dPdlnrho, lrpar, rpar, lipar, ipar, ierr)
       ! returns with ierr = 0 if was able to evaluate lnP and dlnP/dlnrho at rho
       use constants_def
       use nucchem_def
       use nucchem_lib
       use dStar_eos_lib

       integer, intent(in) :: lrpar, lipar
       real(dp), intent(in) :: lnrho
       real(dp), intent(out) :: dPdlnrho
       integer, intent(inout), pointer :: ipar(:) ! (lipar)
       real(dp), intent(inout), pointer :: rpar(:) ! (lrpar)
       integer, intent(out) :: ierr
       real(dp) :: rho, T, P, chi, Pwant
       integer :: eos_handle, ncharged, phase
       type(composition_info_type) :: ionic
       real(dp), dimension(num_dStar_eos_results) :: res
       integer, pointer, dimension(:) :: charged_ids=>null()
       real(dp), pointer, dimension(:) :: Yion=>null()

       ierr = 0

       ! unpack the arguments
       rho = exp(lnrho)
       ionic = composition_info_type(A = rpar(icomp_A), &
       &    Z = rpar(icomp_Z), &
       &    Z53 = rpar(icomp_Z53), &
       &    Z2 = rpar(icomp_Z2), &
       &    Z73 = rpar(icomp_Z73), &
       &    Z52 = rpar(icomp_Z52), &
       &    ZZ1_32 = rpar(icomp_ZZ1_32), &
       &    Z2XoA2 = rpar(icomp_Z2XoA2), &
       &    Ye = rpar(icomp_Ye), &
       &    Yn = rpar(icomp_Yn), &
       &    Q = rpar(icomp_Q) )
       T = rpar(itemp)
       Pwant = rpar(ipres)

       eos_handle = ipar(ihandle)
       ncharged = ipar(iNcharged)
       charged_ids=>ipar(number_base_ipar+1:number_base_ipar+ncharged)
       Yion=>rpar(number_base_rpar+1:number_base_rpar+ncharged)
       chi = use_default_nuclear_size

       call eval_crust_eos(eos_handle,rho,T,ionic,ncharged,charged_ids,Yion, &
               &   res,phase,chi)

       P = exp(res(i_lnP))
       dPdlnrho = P*res(i_chiRho)

       eval_pressure = P - Pwant
    end function eval_pressure

end module bc09
