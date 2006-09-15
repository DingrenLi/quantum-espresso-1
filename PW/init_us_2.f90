!
! Copyright (C) 2001 PWSCF group
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
#include "f_defs.h"
!
!----------------------------------------------------------------------
subroutine init_us_2 (npw_, igk_, q_, vkb_)
  !----------------------------------------------------------------------
  !
  !   Calculates beta functions (Kleinman-Bylander projectors), with
  !   structure factor, for all atoms, in reciprocal space
  !
  USE kinds,      ONLY : DP
  USE ions_base,  ONLY : nat, ntyp => nsp, ityp, tau
  USE cell_base,  ONLY : tpiba
  USE constants,  ONLY : tpi
  USE gvect,      ONLY : eigts1, eigts2, eigts3, ig1, ig2, ig3, g
  USE wvfct,      ONLY : npw, npwx, igk
#ifdef USE_SPLINES
  USE us,         ONLY : nqxq, dq, tab, tab_d2y
  USE splinelib
#else
  USE us,         ONLY : dq, tab
#endif
  USE uspp,       ONLY : nkb, vkb, nhtol, nhtolm, indv
  USE uspp_param, ONLY : lmaxkb, nbeta, nhm, nh
  !
  implicit none
  !
  integer :: npw_, igk_ (npw_)
  ! input: number of PW's
  ! input: indices of q+G
  real(DP) :: q_(3)
  ! input: q vector
  complex(DP) :: vkb_ (npwx, nkb)
  ! output: beta functions
  !
  !     Local variables
  !
  integer :: i0,i1,i2,i3, ig, l, lm, na, nt, nb, ih, jkb

  real(DP) :: px, ux, vx, wx, arg
  real(DP), allocatable :: gk (:,:), qg (:), vq (:), ylm (:,:), vkb1(:,:)

  complex(DP) :: phase, pref
  complex(DP), allocatable :: sk(:)

#ifdef USE_SPLINES
  real(DP), allocatable :: xdata(:)
  integer :: startq, lastq, iq
#endif

  !
  !
  if (lmaxkb.lt.0) return
  call start_clock ('init_us_2')
  allocate (vkb1( npw_,nhm))    
  allocate (  sk( npw_))    
  allocate (  qg( npw_))    
  allocate (  vq( npw_))    
  allocate ( ylm( npw_, (lmaxkb + 1) **2))    
  allocate (  gk( 3, npw_))    
  !
  do ig = 1, npw_
     gk (1,ig) = q_(1) + g(1, igk_(ig) )
     gk (2,ig) = q_(2) + g(2, igk_(ig) )
     gk (3,ig) = q_(3) + g(3, igk_(ig) )
     qg (ig) = gk(1, ig)**2 +  gk(2, ig)**2 + gk(3, ig)**2
  enddo
  !
  call ylmr2 ((lmaxkb+1)**2, npw_, gk, qg, ylm)
  !
  ! set now qg=|q+G| in atomic units
  !
  do ig = 1, npw_
     qg(ig) = sqrt(qg(ig))*tpiba
  enddo

#ifdef USE_SPLINES
  call divide (nqxq, startq, lastq)
  allocate(xdata(lastq-startq+1))
  do iq = startq, lastq
    xdata(iq) = (iq - 1) * dq
  enddo
#endif

  jkb = 0
  do nt = 1, ntyp
     ! calculate beta in G-space using an interpolation table
     do nb = 1, nbeta (nt)
        do ig = 1, npw_
#ifdef USE_SPLINES
           vq(ig) = splint(xdata, tab(:,nb,nt), tab_d2y(:,nb,nt), qg(ig))
#else
           px = qg (ig) / dq - int (qg (ig) / dq)
           ux = 1.d0 - px
           vx = 2.d0 - px
           wx = 3.d0 - px
           i0 = INT( qg (ig) / dq ) + 1
           i1 = i0 + 1
           i2 = i0 + 2
           i3 = i0 + 3
           vq (ig) = tab (i0, nb, nt) * ux * vx * wx / 6.d0 + &
                     tab (i1, nb, nt) * px * vx * wx / 2.d0 - &
                     tab (i2, nb, nt) * px * ux * wx / 2.d0 + &
                     tab (i3, nb, nt) * px * ux * vx / 6.d0
#endif
        enddo
        ! add spherical harmonic part
        do ih = 1, nh (nt)
           if (nb.eq.indv (ih, nt) ) then
              l = nhtol (ih, nt)
              lm =nhtolm (ih, nt)
              do ig = 1, npw_
                 vkb1 (ig,ih) = ylm (ig, lm) * vq (ig)
              enddo
           endif
        enddo
     enddo
     !
     ! vkb1 contains all betas including angular part for type nt
     ! now add the structure factor and factor (-i)^l
     !
     do na = 1, nat
        ! ordering: first all betas for atoms of type 1
        !           then  all betas for atoms of type 2  and so on
        if (ityp (na) .eq.nt) then
           arg = (q_(1) * tau (1, na) + &
                  q_(2) * tau (2, na) + &
                  q_(3) * tau (3, na) ) * tpi
           phase = CMPLX (cos (arg), - sin (arg) )
           do ig = 1, npw_
              sk (ig) = eigts1 (ig1(igk_(ig)), na) * &
                        eigts2 (ig2(igk_(ig)), na) * &
                        eigts3 (ig3(igk_(ig)), na)
           enddo
           do ih = 1, nh (nt)
              jkb = jkb + 1
              pref = (0.d0, -1.d0) **nhtol (ih, nt) * phase
              do ig = 1, npw_
                 vkb_(ig, jkb) = vkb1 (ig,ih) * sk (ig) * pref
              enddo
           enddo
        endif
     enddo
  enddo
  deallocate (gk)
  deallocate (ylm)
  deallocate (vq)
  deallocate (qg)
  deallocate (sk)
  deallocate (vkb1)

  call stop_clock ('init_us_2')
  return
end subroutine init_us_2

