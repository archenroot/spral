module spral_ssids_factor_cpu_iface
   use, intrinsic :: iso_c_binding
   use spral_ssids_akeep, only : ssids_akeep_base
   use spral_ssids_datatypes, only : ssids_options
   use spral_ssids_inform, only : ssids_inform_base
   implicit none

   private
   public :: cpu_node_data, cpu_factor_options, cpu_factor_stats
   public :: factor_cpu, setup_cpu_data, extract_cpu_data

   !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

   ! See comments in C++ definition in factor_gpu.cxx for detail
   type, bind(C) :: cpu_node_data
      ! Fixed data from analyse
      integer(C_INT) :: nrow_expected
      integer(C_INT) :: ncol_expected
      type(C_PTR) :: first_child
      type(C_PTR) :: next_child
      type(C_PTR) :: rlist

      ! Data about A
      integer(C_INT) :: num_a
      type(C_PTR) :: amap

      ! Data that changes during factorize
      integer(C_INT) :: ndelay_in
      integer(C_INT) :: ndelay_out
      integer(C_INT) :: nelim
      type(C_PTR) :: lcol
      type(C_PTR) :: perm
      type(C_PTR) :: contrib
   end type cpu_node_data

   !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

   type, bind(C) :: cpu_factor_options
      real(C_DOUBLE) :: small
      real(C_DOUBLE) :: u
   end type cpu_factor_options

   !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

   type, bind(C) :: cpu_factor_stats
      integer(C_INT) :: flag
   end type cpu_factor_stats

   !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

   interface
      subroutine factor_cpu(pos_def, nnodes, nodes, aval, scaling, &
            alloc, options, stats) &
            bind(C, name="spral_ssids_factor_cpu_dbl")
         use, intrinsic :: iso_c_binding
         import :: cpu_node_data, cpu_factor_options, cpu_factor_stats
         implicit none
         logical(C_BOOL), value :: pos_def
         integer(C_INT), value :: nnodes
         type(cpu_node_data), dimension(nnodes), intent(inout) :: nodes
         real(C_DOUBLE), dimension(*), intent(in) :: aval
         real(C_DOUBLE), dimension(*), intent(in) :: scaling
         type(C_PTR), value :: alloc
         type(cpu_factor_options), intent(in) :: options
         type(cpu_factor_stats), intent(out) :: stats
      end subroutine factor_cpu
   end interface

contains

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

subroutine setup_cpu_data(akeep, cnodes, foptions, coptions)
   class(ssids_akeep_base), target, intent(in) :: akeep
   type(cpu_node_data), dimension(akeep%nnodes), target, intent(out) :: cnodes
   type(ssids_options), intent(in) :: foptions
   type(cpu_factor_options), intent(out) :: coptions

   integer :: node, parent

   !
   ! Setup node data
   !
   ! Basic data and initialize linked lists
   do node = 1, akeep%nnodes
      ! Data about factors
      cnodes(node)%nrow_expected = akeep%rptr(node+1) - akeep%rptr(node)
      cnodes(node)%ncol_expected = akeep%sptr(node+1) - akeep%sptr(node)
      cnodes(node)%first_child = C_NULL_PTR
      cnodes(node)%next_child = C_NULL_PTR
      cnodes(node)%rlist = C_LOC(akeep%rlist(akeep%rptr(node)))

      ! Data about A
      cnodes(node)%num_a = akeep%nptr(node+1) - akeep%nptr(node)
      cnodes(node)%amap = C_LOC(akeep%nlist(1,akeep%nptr(node)))
   end do
   ! Build linked lists of children
   do node = 1, akeep%nnodes
      parent = akeep%sparent(node)
      cnodes(node)%next_child = cnodes(parent)%first_child
      cnodes(parent)%first_child = C_LOC( cnodes(node) )
   end do

   !
   ! Setup options
   !
   coptions%small = foptions%small
   coptions%u     = foptions%u
end subroutine setup_cpu_data

subroutine extract_cpu_data(cstats, finform)
   type(cpu_factor_stats), intent(in) :: cstats
   class(ssids_inform_base), intent(inout) :: finform
end subroutine extract_cpu_data

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
end module spral_ssids_factor_cpu_iface
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

! Provide a way to alloc memory using smalloc (double version)
type(C_PTR) function spral_ssids_smalloc_dbl(calloc, len) bind(C)
   use, intrinsic :: iso_c_binding
   use spral_ssids_datatypes, only : long, smalloc_type
   use spral_ssids_alloc, only : smalloc
   implicit none
   type(C_PTR), value :: calloc
   integer(C_SIZE_T), value :: len

   type(smalloc_type), pointer :: falloc, srcptr
   real(C_DOUBLE), dimension(:), pointer :: ptr
   integer(long) :: srchead
   integer :: st

   call c_f_pointer(calloc, falloc)
   call smalloc(falloc, ptr, len, srcptr, srchead, st)
   if(st.ne.0) then
      spral_ssids_smalloc_dbl = C_NULL_PTR
   else
      spral_ssids_smalloc_dbl = C_LOC(srcptr%rmem(srchead))
   endif
end function spral_ssids_smalloc_dbl

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Provide a way to alloc memory using smalloc (int version)
type(C_PTR) function spral_ssids_smalloc_int(calloc, len) bind(C)
   use, intrinsic :: iso_c_binding
   use spral_ssids_datatypes, only : long, smalloc_type
   use spral_ssids_alloc, only : smalloc
   implicit none
   type(C_PTR), value :: calloc
   integer(C_SIZE_T), value :: len

   type(smalloc_type), pointer :: falloc, srcptr
   integer(C_INT), dimension(:), pointer :: ptr
   integer(long) :: srchead
   integer :: st

   call c_f_pointer(calloc, falloc)
   call smalloc(falloc, ptr, len, srcptr, srchead, st)
   if(st.ne.0) then
      spral_ssids_smalloc_int = C_NULL_PTR
   else
      spral_ssids_smalloc_int = C_LOC(srcptr%imem(srchead))
   endif
end function spral_ssids_smalloc_int
