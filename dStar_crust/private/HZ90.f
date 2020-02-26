module hz90

    use const_def, only: dp
    use nucchem_def, only: iso_name_length
    
    real(dp), parameter :: transition_width = 0.02
    
    integer, parameter :: HZ90_number = 19
    integer, parameter :: HZ08_number = 34
    character(len=iso_name_length), parameter, dimension(HZ90_number) :: HZ90_network = [ character(len=iso_name_length) :: &
    &   'n', &
    &   'mg40', &
    &   'mg44', &
    &   'mg48', &
    &   'si46', &
    &   'si50', &
    &   'si54', &
    &   's52', &
    &   's56', &
    &   's60', &
    &   'ar56', &
    &   'ar62', &
    &   'ar66', &
    &   'ca56', &
    &   'ca68', &
    &   'ti56', &
    &   'ti88',  &
    &   'cr56', &
    &   'fe56' ]
    
    character(len=iso_name_length), parameter, dimension(HZ08_number) :: HZ08_network = [ character(len=iso_name_length) :: &
    &   'n', &
    &   'ne36', &
    &   'mg46', &
    &   'mg42', &
    &   'si50', &
    &   'si54', &
    &   'si62', &
    &   's56', &
    &   's60', &
    &   's68', &
    &   'ar62', &
    &   'ar66', &
    &   'ar74', &
    &   'ca68', &
    &   'ca72', &
    &   'ca80', &
    &   'ti74', &
    &   'ti86', &
    &   'ti116', &
    &   'cr80', &
    &   'cr92', &
    &   'cr118', &
    &   'fe86', &
    &   'fe120', &
    &   'ni92', &
    &   'ni124', &
    &   'ge106', &
    &   'se106', &
    &   'kr106', &
    &   'sr106', &
    &   'zr106', &
    &   'mo106', &
    &   'ru106', &
    &   'pd106' ]
    
    integer, parameter :: n_rxns = 17
    integer, parameter :: n_layers = n_rxns+1
    character(len=iso_name_length), parameter, dimension(n_layers) :: &
    &   ion_composition = [ character(len=iso_name_length) :: &
    &   'fe56','cr56','ti56','ca56','ar56','s52', &
    &   'si46','mg40','ca68', 'ar62','s56','si50', &
    &   'mg44','ar66','s60','si54','mg48','ti88' ]
    
    real(dp),parameter, dimension(n_rxns) :: transition_pressures = [ &
    &   7.235d26,9.569d27,1.152d29,4.747d29,1.361d30,1.980d30, &
    &   2.253d30,2.637d30,2.771d30,3.216d30, 3.825d30,4.699d30, &
    &   6.043d30,7.233d30,9.238d30,1.228d31,1.602d31 ]

    real(dp), parameter, dimension(n_layers) :: Xn = [ &
    &   0.0, 0.0, 0.0, 0.0, 0.0,  0.07,  &
    &   0.18, 0.29, 0.39, 0.45, 0.50, 0.55, &
    &   0.61, 0.70, 0.73, 0.76, 0.80, 0.80]


    ! for Haensel & Zdunik 2008 **not implemented**
    integer, parameter :: n_HZ08_rxns= 29
    integer, parameter :: n_HZ08_layers = n_HZ08_rxns+1
    character(len=iso_name_length),parameter,dimension(n_HZ08_layers):: &
     HZ08_ion_composition = [ character(len=iso_name_length) ::  &
    &   'pd106', 'ru106', 'mo106', 'zr106', 'sr106', 'kr106',  &
    &   'se106', 'ge106', 'ni92', 'fe86', 'cr80', 'ti74', &
    &   'ca68', 'ar62', 's56', 'si50', 'mg42', 'ca72',  &
    &   'ar66', 's60', 'si54', 'cr92', 'ti86', 'ca80',  &
    &   'ar74', 's68', 'ni124', 'fe120', 'cr118', 'ti116' ]

contains
    
    subroutine set_HZ90_composition(lgP, Y)
        use const_def, only: dp, pi
        use nucchem_def
        use nucchem_lib
        real(dp), intent(in), dimension(:) :: lgP
        real(dp), intent(out), dimension(:,:) :: Y ! (HZ90_number, size(lgP))
        integer, dimension(max_nnuclib) :: network_indcs
        integer :: Ntab, i, indx, n_indx, indx1, indx2
        integer, dimension(HZ90_number) :: indcs
        real(dp), dimension(n_rxns) :: lg_Pt
        real(dp) :: lgP1, lgP2, width, Xsum
        real(dp), allocatable, dimension(:,:) :: X
        
        Ntab = size(lgP)
        allocate(X(HZ90_number,Ntab))
        Y = 0.0
        lg_Pt = log10(transition_pressures)
        
        ! set the network pointers
        indcs = [(get_nuclide_index(HZ90_network(i)),i=1,HZ90_number)]
        ! and the reverse lookup
        network_indcs = 0
        network_indcs(indcs) = [(i,i=1,HZ90_number)]
        n_indx = network_indcs(get_nuclide_index('n'))
        
        ! set the compositon layer by layer, starting at the top
        ! first layer (pressures up to the first transition)
        indx = network_indcs(get_nuclide_index(ion_composition(1)))
        where(lgP <= lg_Pt(1)) 
            X(n_indx,:) = Xn(1)
            X(indx,:) = 1.0-Xn(1)
        end where
        ! subsequent layers
        do i = 2, n_rxns
            indx = network_indcs(get_nuclide_index(ion_composition(i)))
            where(lgP > lg_Pt(i-1) .and. lgP <= lg_Pt(i))
                X(n_indx,:) = Xn(i)
                X(indx,:) = 1.0-Xn(i)
            end where
        end do
        ! pressures above the last transition
        indx = &
        &   network_indcs(get_nuclide_index(ion_composition(n_layers)))
        where (lgP > lg_Pt(n_rxns))
            X(n_indx,:) = Xn(n_layers)
            X(indx,:) = 1.0-Xn(n_layers)
        end where
        
        ! now smooth the transitions
        do i = 1, n_rxns
            lgP1 = lg_Pt(i) - transition_width
            lgP2 = lg_Pt(i) + transition_width
            width = 2.0*transition_width
            indx1 = network_indcs(get_nuclide_index(ion_composition(i)))
            indx2 = network_indcs(get_nuclide_index(ion_composition(i+1)))
            where(lgP >= lgP1 .and. lgP <= lgP2)
                X(n_indx,:) = (Xn(i)-Xn(i+1))*cos(0.5*pi*(lgP-lgP1)/width) + Xn(i+1)
                X(indx1,:) = (1.0-X(n_indx,:))*cos(0.5*pi*(lgP-lgP1)/width)
                X(indx2,:) = (1.0-X(n_indx,:))*(1.0 - cos(0.5*pi*(lgP-lgP1)/width))
            end where
        end do

        ! convert to abundances
        forall(i=1:HZ90_number) Y(i,:) = X(i,:)/nuclib% A(indcs(i))
    
    end subroutine set_HZ90_composition

    subroutine find_densities(eos_handle,lgP,lgRho,lgEps,Yion)
        real(dp) :: Pfac
        integer, intent(in) :: eos_handle
        real(dp), dimension(:), intent(in) :: lgP
        real(dp), dimension(:), intent(out) :: lgRho
        real(dp), dimension(:), intent(out) :: lgEps
        real(dp), dimension(:,:), intent(in) :: Yion
        integer, intent(in) :: ncharged
        integer, dimension(:), intent(in) :: charged_ids
        real(dp), intent(in) :: Tref
        type(composition_info_type), dimension(:), intent(in) :: ionic
        real(dp), dimension(:), pointer :: rpar=>null()
        integer, dimension(:), pointer :: ipar=>null()
        integer :: lipar, lrpar
        integer :: i,Ntab
        real(dp) :: x1, x3, y1, y3, epsx, epsy, lgRho_guess
        integer :: imax, ierr
        
        Pfac = 0.25*(threepisquare)**onethird *hbar*clight*avo**(4.0*onethird)
        Ntab = size(lgP)
        imax = 20
        epsx = 1.0d-8
        epsy = 1.0d-8
        
        ! decide the size of the parameter arrays
        lipar = 2 + ncharged
        allocate(ipar(lipar))
        ipar(1) = eos_handle
        ipar(2) = ncharged
        ipar(3:ncharged+2) = charged_ids(1:ncharged)
        
        lrpar = ncharged + 11 + 4
        allocate(rpar(lrpar))
        
        ! last value of rpar is a guess for the density; if 0, will be calculated for relativistic electron gas
        rpar(lrpar) = 0.0
        do i = 1, Ntab
            ! stuff the composition information into the parameter array
            rpar(1:ncharged) = Yion(1:ncharged,i)
            rpar(ncharged+1) = ionic(i)% A
            rpar(ncharged+2) = ionic(i)% Z
            rpar(ncharged+3) = ionic(i)% Z53
            rpar(ncharged+4) = ionic(i)% Z2
            rpar(ncharged+5) = ionic(i)% Z73
            rpar(ncharged+6) = ionic(i)% Z52
            rpar(ncharged+7) = ionic(i)% ZZ1_32
            rpar(ncharged+8) = ionic(i)% Z2XoA2
            rpar(ncharged+9) = ionic(i)% Ye
            rpar(ncharged+10) = ionic(i)% Yn
            rpar(ncharged+11) = ionic(i)% Q
            rpar(ncharged+12) = lgP(i)
            rpar(ncharged+13) = Tref
            
            if (i > 1 .and. rpar(lrpar) /= 0.0) then
                lgRho_guess = lgRho(i-1) + (lgP(i)-lgP(i-1))/rpar(lrpar)
            else
                lgRho_guess = log10((10.0**lgP(i)/Pfac)**0.75 /ionic(i)% Ye)
            end if
            
            call look_for_brackets(lgRho_guess,0.05*lgRho_guess,x1,x3,match_density, &
            &   y1,y3,imax,lrpar,rpar,lipar,ipar,ierr)
            if (ierr /= 0) then
                write (*,*) 'unable to bracket root',lgP(i), x1, x3, y1, y3
                cycle
            end if
            
            lgRho(i) = safe_root_with_initial_guess(match_density,lgRho_guess,x1,x3,y1,y3, &
            &   imax,epsx,epsy,lrpar,rpar,lipar,ipar,ierr)
            if (ierr /= 0) then
                write(*,*) 'unable to converge', lgP(i), x1, x3, y1, y3
                cycle
            end if
            lgEps(i) = rpar(ncharged+14)
        end do
    end subroutine find_densities
    
    real(dp) function match_density(lgRho, dfdlgRho, lrpar, rpar, lipar, ipar, ierr)
       ! returns with ierr = 0 if was able to evaluate f and df/dx at x
       ! if df/dx not available, it is okay to set it to 0
       use constants_def
       use superfluid_def, only: max_number_sf_types
       use superfluid_lib, only: sf_get_results
       use nucchem_def
       use dStar_eos_def
       use dStar_eos_lib
       
       integer, intent(in) :: lrpar, lipar
       real(dp), intent(in) :: lgRho
       real(dp), intent(out) :: dfdlgRho
       integer, intent(inout), pointer :: ipar(:) ! (lipar)
       real(dp), intent(inout), pointer :: rpar(:) ! (lrpar)
       integer, intent(out) :: ierr
       integer :: eos_handle, ncharged
       type(composition_info_type) :: ionic
       integer, dimension(:), allocatable :: charged_ids
       real(dp), dimension(:), allocatable :: Yion
       real(dp), dimension(num_dStar_eos_results) :: res
       integer :: phase
       real(dp) :: chi, lgPwant, lgP, kFn, kFp, Tcs(max_number_sf_types)
       real(dp) :: rho, T, Eint
       
       eos_handle = ipar(1)
       ncharged = ipar(2)
       allocate(charged_ids(ncharged),Yion(ncharged))
       charged_ids(:) = ipar(3:ncharged+2)
       
       Yion = rpar(1:ncharged)
       ionic% A = rpar(ncharged+1)
       ionic% Z = rpar(ncharged+2)
       ionic% Z53 = rpar(ncharged+3)
       ionic% Z2 = rpar(ncharged+4)
       ionic% Z73 = rpar(ncharged+5)
       ionic% Z52 = rpar(ncharged+6)
       ionic% ZZ1_32 = rpar(ncharged+7)
       ionic% Z2XoA2 = rpar(ncharged+8)
       ionic% Ye = rpar(ncharged+9)
       ionic% Yn = rpar(ncharged+10)
       ionic% Q = rpar(ncharged+11)
       
       rho = 10.0**lgRho
       T = rpar(ncharged+13)
       chi = nuclear_volume_fraction(rho,ionic,default_nuclear_radius)
       kFp = 0.0_dp
       kFn = neutron_wavenumber(rho,ionic,chi)
       call sf_get_results(kFp,kFn,Tcs)
       call eval_crust_eos(eos_handle,rho,T,ionic,ncharged, &
       &    charged_ids,Yion,Tcs,res,phase,chi)
       Eint = res(i_lnE)
       
       lgPwant = rpar(ncharged+12)
       lgP = res(i_lnP)/ln10

!         ! compute composition moments
!         do i = 1, Ntab
!             call compute_composition_moments(HZ90_number, indcs, X(:,i), &
!             &   ion_info(i), Xsum, ncharged, charged_ids, Yion(:,i), &
!             &   abunds_are_mass_fractions=.TRUE., exclude_neutrons=.TRUE.)
!         end do
        deallocate(X)
    end subroutine set_HZ90_composition

end module hz90
