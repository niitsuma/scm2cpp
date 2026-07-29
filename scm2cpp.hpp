#ifndef SCM2CPP
#define SCM2CPP

#include <iostream>
#include <vector>
#include <list>
#include <map>
#include <algorithm>
#include <cstdarg>

//#include <type_traits>
#include <functional>

#include <boost/rational.hpp>
#include <boost/math/complex.hpp>

#include <boost/array.hpp>

#include <boost/function.hpp>
#include <boost/functional.hpp>

//#include <boost/thread.hpp>

#include <boost/typeof/typeof.hpp>
#include <boost/type_traits.hpp>
#include <boost/utility/result_of.hpp>
#include <boost/function_types/result_type.hpp>
#include <boost/function_types/parameter_types.hpp>
#include <boost/function_types/function_type.hpp>

#include <boost/preprocessor.hpp>

#include <boost/ptr_container/ptr_vector.hpp>
#include <boost/ptr_container/ptr_list.hpp>
#include <boost/ptr_container/ptr_array.hpp>
#include <boost/ptr_container/ptr_inserter.hpp>
#include <boost/ptr_container/clone_allocator.hpp>

#include <boost/utility/enable_if.hpp>

#include <boost/mpl/vector.hpp>
#include <boost/mpl/contains.hpp>
#include <boost/mpl/transform.hpp>
#include <boost/mpl/insert_range.hpp>
#include <boost/mpl/identity.hpp>
#include <boost/mpl/logical.hpp>

#include <boost/mpl/less.hpp>
#include <boost/mpl/comparison.hpp>
#include <boost/mpl/filter_view.hpp>
#include <boost/mpl/sizeof.hpp>
#include <boost/mpl/vector.hpp>
#include <boost/mpl/sort.hpp>
#include <boost/mpl/equal.hpp>
#include <boost/mpl/assert.hpp>
#include <boost/mpl/if.hpp>
#include <boost/mpl/set.hpp>
#include <boost/mpl/empty.hpp>
#include <boost/mpl/unique.hpp>

//#include <boost/fusion/iterator.hpp>
//#include <boost/fusion/include/iterator.hpp>


#include <boost/fusion/container/vector.hpp>
#include <boost/fusion/algorithm.hpp>
#include <boost/fusion/sequence.hpp>
#include <boost/fusion/include/list.hpp>
#include <boost/fusion/include/vector.hpp>

#include <boost/fusion/container/list/cons.hpp>
#include <boost/fusion/include/cons.hpp>
#include <boost/fusion/include/make_cons.hpp>
#include <boost/fusion/container/generation/make_cons.hpp>
#include <boost/fusion/container/generation/make_list.hpp>
#include <boost/fusion/include/make_list.hpp>


#include <boost/fusion/iterator/iterator_facade.hpp>
#include <boost/fusion/include/iterator_facade.hpp>

#include <boost/fusion/algorithm/auxiliary/copy.hpp>
#include <boost/fusion/include/copy.hpp>

#include <boost/fusion/algorithm/transformation/push_front.hpp>
#include <boost/fusion/include/push_front.hpp>

#include <boost/fusion/algorithm/transformation/push_back.hpp>
#include <boost/fusion/include/push_back.hpp>


#include <boost/variant.hpp>


#define null_P scm2cpp::is_null
#define eq_P scm2cpp::is_eq
#define eqv_P scm2cpp::is_eqv
#define equal_P scm2cpp::is_equal




#define CONSED_AS_STD_PAIR 1
#if CONSED_AS_STD_PAIR
#define consd std::pair
#endif

// #include <boost/intrusive/slist.hpp>
// #include <boost/intrusive/list.hpp>
// #include <boost/intrusive/list_hook.hpp>

namespace scm2cpp
{



  template<typename T> std::auto_ptr<T> ptr_r2lvalue(const T& v){return std::auto_ptr<T>(new T(v));}
  //template<typename T> T& r2lvalue(const T& v){return *p_r2lvalue(v);}


  typedef boost::fusion::nil nil_type;
  typedef boost::fusion::nil nil;
  typedef boost::fusion::nil null_type;
 
  //nil_type null;
  nil_type null();
  //nil_type nil();
  //nil_type & nil = null;

  typedef std::string string_type;
  
  struct symbol_type : public string_type
  { symbol_type(string_type & st) : string_type(st)    {}
    symbol_type(char *c) : string_type(c) {}  };

  symbol_type string_to_symbol(string_type &st){return symbol_type(st);}
  string_type symbol_to_string(symbol_type &st){return st;}


  typedef boost::mpl::vector<char,int,short,long,float,double,bool> c_number_types;
  typedef boost::mpl::vector<boost::rational<int>,std::complex<double> > not_c_number_types;
  typedef boost::mpl::insert_range<c_number_types,boost::mpl::end<c_number_types>::type,not_c_number_types>::type number_types;

  typedef boost::mpl::push_back<number_types,string_type>::type number_string_types;
  typedef boost::mpl::push_back<number_types,symbol_type>::type number_symbol_types;  
  typedef boost::mpl::push_back<number_string_types,symbol_type>::type number_string_symbol_types;
  typedef boost::mpl::push_back<not_c_number_types,string_type>::type not_c_number_string_types;
  typedef boost::mpl::push_back<not_c_number_string_types,symbol_type>::type not_c_number_string_symbol_types;


  template<typename Base
	   , class Enable = void	   
	   >	   
  struct quoted 
  : Base
  { Base & value;     quoted(Base & base):Base(base),value(base)     {} };


  template<typename Base
	   //, class Enable = void
	   //,typename boost::disable_if<boost::is_arithmetic<Base> >::type
	   >	   
  //struct quoted 
  struct quoted<Base
		,typename boost::disable_if<boost::is_arithmetic<Base> >::type>
  : Base
  { Base & value;     quoted(Base & base):Base(base),value(base)     {} };
  
  template<typename Base>
  struct quoted<Base
		,typename boost::enable_if<boost::is_arithmetic<Base> >::type>
#if 0
    :
    less_than_comparable < quoted<Base>,
    equality_comparable < quoted<Base>,
    less_than_comparable2 < quoted<Base>, Base,
    equality_comparable2 < quoted<Base>, Base,
    addable < quoted<Base>,
    subtractable < quoted<Base>,
    multipliable < quoted<Base>,
    dividable < quoted<Base>,
    addable2 < quoted<Base>, Base,
    subtractable2 < quoted<Base>, Base,
    subtractable2_left < quoted<Base>, Base,
    multipliable2 < quoted<Base>, Base,
    dividable2 < quoted<Base>, Base,
    dividable2_left < quoted<Base>, Base,
    incrementable < quoted<Base>,
    decrementable < quoted<Base>
    > > > > > > > > > > > > > > > >
#endif
  : boost::operators<quoted<Base> >
  {    
    Base value;
    quoted(Base base):value(base)     {} 
    bool operator<(const quoted<Base>& x) const { return value < x.value; }
    bool operator==(const quoted<Base>& x) const { return value == x.value; }
    quoted<Base>& operator+=(const quoted<Base>& x) { value+=x.value; return *this; }
    quoted<Base>& operator-=(const quoted<Base>& x) { value-=x.value; return *this; }
    quoted<Base>& operator*=(const quoted<Base>& x) { value*=x.value; return *this; }
    quoted<Base>& operator/=(const quoted<Base>& x) { value/=x.value; return *this; }
    quoted<Base>& operator%=(const quoted<Base>& x) { value%=x.value; return *this; }
    quoted<Base>& operator|=(const quoted<Base>& x) { value|=x.value; return *this; }
    quoted<Base>& operator&=(const quoted<Base>& x) { value&=x.value; return *this; }
    quoted<Base>& operator^=(const quoted<Base>& x) { value^=x.value; return *this; }
    quoted<Base>& operator++()                 { ++value;       return *this; }
    quoted<Base>& operator--()                 { --value;       return *this; }

  };


  
  template<typename Base> quoted<Base> quote(Base &base){return quoted<Base>(base); }

  template<typename Base> quoted<Base> 
  quote(Base base,typename boost::enable_if<boost::is_arithmetic<Base>, Base>::type* = 0)
  {return quoted<Base>(base);}


  
  template<typename Base>
  struct unquoted
  {    Base & value;    
    unquoted(Base &base):value(base)
    {}  };
  
  template<typename Base>  unquoted<Base> unquote(Base &base){return unquoted<Base>(base); }

  template<typename Base>
  struct quasiquoted 
  {    Base & value;    
    quasiquoted(Base &base):value(base)
    {}  };

  template<typename Base>  quasiquoted <Base> quasiquote(Base &base){return quasiquoted<Base>(base); }


#if 1
  typedef boost::mpl::transform< number_string_types,quoted<boost::mpl::_1> >::type quoted_number_string_types ;  
  typedef boost::mpl::insert_range<quoted_number_string_types,
			   boost::mpl::end<quoted_number_string_types>::type,
			   number_string_symbol_types>::type value_types;

 
  typedef boost::mpl::transform< number_types,quoted<boost::mpl::_1> >::type quoted_number_types ;  
  typedef boost::mpl::insert_range<quoted_number_types,
			   boost::mpl::end<quoted_number_types>::type,
			   number_symbol_types>::type scalar_types;

  typedef boost::mpl::vector<char,int,short,long> int_types;
  typedef boost::mpl::transform<int_types, quoted<boost::mpl::_1> >::type quoted_int_types ;  
  typedef boost::mpl::insert_range<quoted_int_types,
			   boost::mpl::end<quoted_int_types>::type,
			   int_types>::type int_quote_types;
#endif


  
  /////////////////////////list begin///////////////////////////////////

#if CONSED_AS_STD_PAIR 
#else
  template<typename C ,typename D>  struct 
  consed : std::pair<C,D> {};
#endif
#if 0
  template<typename Seqs ,typename Last>  struct 
  appended : std::pair<Seqs,Last> {};
#else
  template<typename Seqs>  struct 
  appended 
  {
    Seqs &value;
    appended(const Seqs & seqs):value(seqs){}
  };

#endif

  //s8vector 	signed exact integer in the range -(2^7) to (2^7)-1
  // u8vector 	unsigned exact integer in the range 0 to (2^8)-1
  // s16vector	signed exact integer in the range -(2^15) to (2^15)-1
  // u16vector	unsigned exact integer in the range 0 to (2^16)-1
  // s32vector	signed exact integer in the range -(2^31) to (2^31)-1
  // u32vector	unsigned exact integer in the range 0 to (2^32)-1
  // s64vector	signed exact integer in the range -(2^63) to (2^63)-1
  // u64vector	unsigned exact integer in the range 0 to (2^64)-1 

  typedef boost::ptr_vector<float, boost::view_clone_allocator> f32ptr_vector;
  typedef boost::ptr_vector<double, boost::view_clone_allocator> f64ptr_vector;
  typedef boost::ptr_list<float, boost::view_clone_allocator>   f32ptr_list;
  typedef boost::ptr_list<double, boost::view_clone_allocator>  f64ptr_list;

  typedef boost::ptr_list<char, boost::view_clone_allocator>  u8vector;
  typedef boost::ptr_list<unsigned short, boost::view_clone_allocator>    u16vector;
  typedef boost::ptr_list<unsigned int, boost::view_clone_allocator>    u32vector;
  typedef boost::ptr_list<unsigned long, boost::view_clone_allocator>    u64vector;

  typedef boost::ptr_list<signed char, boost::view_clone_allocator>  s8vector;
  typedef boost::ptr_list<short, boost::view_clone_allocator>   s16vector;
  typedef boost::ptr_list<int, boost::view_clone_allocator>   s32vector;
  typedef boost::ptr_list<long, boost::view_clone_allocator>   s64vector;



  template<typename T> struct is_boost_ptr_sequence_view :public boost::mpl::false_ {};  
  template<typename T> struct is_boost_ptr_sequence_view<boost::ptr_list<T, boost::view_clone_allocator> > :public boost::mpl::true_ {};  
  template<typename T> struct is_boost_ptr_sequence_view<boost::ptr_vector<T, boost::view_clone_allocator> > :public boost::mpl::true_ {};  
  template<typename T,std::size_t N> struct is_boost_ptr_sequence_view<boost::ptr_array<T,N, boost::view_clone_allocator> > :public boost::mpl::true_ {};

  
  template<typename T,typename E> struct is_boost_ptr_sequence_view_of :public boost::mpl::false_ {};  
  template<typename T> struct is_boost_ptr_sequence_view_of<boost::ptr_list<T, boost::view_clone_allocator>,T> :public boost::mpl::true_ {};  
  template<typename T> struct is_boost_ptr_sequence_view_of<boost::ptr_vector<T, boost::view_clone_allocator>,T> :public boost::mpl::true_ {};  
  template<typename T,std::size_t N> struct is_boost_ptr_sequence_view_of<boost::ptr_array<T,N, boost::view_clone_allocator>,T> :public boost::mpl::true_ {};

  template<typename T> struct is_uniform_sequence :public is_boost_ptr_sequence_view<T> {}; 
  template<> struct is_uniform_sequence<std::string > :public boost::mpl::true_ {};
  template<typename T> struct is_uniform_sequence<std::vector<T> > :public boost::mpl::true_ {};
  template<typename T> struct is_uniform_sequence<std::list<T> > :public boost::mpl::true_ {};  
  template<typename T,std::size_t N> struct is_uniform_sequence<boost::array<T,N> >  :public boost::mpl::true_ {};


  template<typename T,typename E> struct is_uniform_sequence_of :public is_boost_ptr_sequence_view_of<T,E> {}; 
  template<> struct is_uniform_sequence_of<std::string,char> :public boost::mpl::true_ {};
  template<typename T> struct is_uniform_sequence_of<std::vector<T>,T> :public boost::mpl::true_ {};
  template<typename T> struct is_uniform_sequence_of<std::list<T>,T> :public boost::mpl::true_ {};  
  template<typename T,std::size_t N> struct is_uniform_sequence_of<boost::array<T,N>,T>  :public boost::mpl::true_ {};
  
  template<typename T> struct uniform_sequence_to_boost_ptr_sequence_view {typedef T type;};
  template<typename T> struct uniform_sequence_to_boost_ptr_sequence_view<std::vector<T> > 
  {typedef boost::ptr_vector<T, boost::view_clone_allocator> type; };
  template<typename T> struct uniform_sequence_to_boost_ptr_sequence_view<std::list<T> > 
  {typedef boost::ptr_list<T, boost::view_clone_allocator> type; };
  template<typename T,std::size_t N> struct   
  uniform_sequence_to_boost_ptr_sequence_view 
  <boost::array<T,N> >
  {typedef boost::ptr_vector<T, boost::view_clone_allocator> type; };///?
  template<typename T> struct
  uniform_sequence_to_boost_ptr_sequence_view 
  <boost::ptr_vector<T, boost::view_clone_allocator> >
  {typedef boost::ptr_vector<T, boost::view_clone_allocator> type; };
  template<typename T> struct   
  uniform_sequence_to_boost_ptr_sequence_view 
  <boost::ptr_list<T, boost::view_clone_allocator> > 
  {typedef boost::ptr_list<T, boost::view_clone_allocator> type; };
  template<typename T,std::size_t N> struct   
  uniform_sequence_to_boost_ptr_sequence_view 
  <boost::ptr_array<T,N, boost::view_clone_allocator> >
  {typedef boost::ptr_vector<T, boost::view_clone_allocator> type; };///?

  template<typename T> struct 
  uniform_sequence_value_type 
  {typedef typename T::value_type type;};
  template<typename T> struct 
  uniform_sequence_value_type 
  <boost::ptr_list<T, boost::view_clone_allocator> > 
  {typedef T type;};
  template<typename T> struct 
  uniform_sequence_value_type 
  <boost::ptr_vector<T, boost::view_clone_allocator> > 
  {typedef T type;};
  template<typename T,std::size_t N> struct 
  uniform_sequence_value_type 
  <boost::ptr_array<T,N, boost::view_clone_allocator> > 
  {typedef T type;};
  template<typename C,typename D> struct 
  uniform_sequence_value_type<std::pair<C,D> > 
  {typedef C type;};


  template<typename T> struct 
  is_sequence : boost::mpl::or_<
    boost::fusion::traits::is_sequence<T>
    ,is_uniform_sequence<T>
    >{};

  template<typename T> struct is_std_pair : boost::mpl::false_ {};
  template<typename C,typename D> struct is_std_pair<std::pair<C,D> > : boost::mpl::true_ {};


  template<typename T> struct 
  is_pair_type : boost::mpl::or_<
    is_sequence<T>
    ,is_std_pair<T>
    >{};
  template<> struct 
  is_pair_type<nil_type> : boost::mpl::false_ {};
  template<typename T> bool is_pair(const T& dummy){return is_pair_type<T>::value; }

  
  template<typename T> struct 
  is_list_type : is_sequence<T> {};
  template<typename C,typename D> struct 
  is_list_type<std::pair<C,D> > : is_list_type<D> {};
  template<typename T> bool is_list(const T& dummy){return is_list_type<T>::value;}  
  



  template<typename T> struct 
  is_subst_ref_object  :public 
  boost::mpl::or_<   
    boost::is_array<T>
    ,boost::fusion::traits::is_sequence<T> 
    ,is_boost_ptr_sequence_view<T>
    ,is_uniform_sequence<T>
    >{};
  template<typename C,typename D> struct 
  is_subst_ref_object<std::pair<C,D> > :public boost::mpl::true_ {};
  template<typename C,typename D> struct 
  is_subst_ref_object<std::map<C,D> > :public boost::mpl::true_ {};

  template<typename T>  struct 
  is_subst_copy_object :public boost::mpl::not_<is_subst_ref_object<T> > {};

  template<typename T> struct to_subst_type : boost::mpl::if_< 
    is_subst_copy_object<T>
    ,boost::mpl::identity<T>
    ,boost::add_reference<T>
    >::type {};
  

  bool is_null(const nil_type  & dummy){return true;}
  template<typename T> bool is_null(const std::list<T> & l){return (l.size()==0);}
  template<typename T> bool is_null(const std::vector<T> & l){return (l.size()==0);}
  template<typename T> bool is_null(const T & dummy){return false;}



  template<typename C, typename D> std::pair<
    typename to_subst_type<C>::type    
    ,typename to_subst_type<D>::type>
  cons(const C & c,const D & d
       ,typename boost::disable_if<boost::mpl::or_<
	 boost::fusion::traits::is_sequence<D>
	 ,is_uniform_sequence_of<D,C>
	 > > ::type* =0 
    ){return std::pair<
      typename to_subst_type<C>::type    
      ,typename to_subst_type<D>::type
      > (const_cast<C &>(c),const_cast<D &>(d)); }
#if 1
  template <typename T,typename Sequence>  
  boost::fusion::cons<typename to_subst_type<T>::type,Sequence > 
  cons(const T & e,
       const Sequence & seq
       ,typename boost::enable_if<
	 boost::fusion::traits::is_sequence<Sequence> 
	 > ::type*  = 0
       ){ return boost::fusion::cons<typename to_subst_type<T>::type,Sequence >(e,seq);}
#else
  template <typename T,typename Sequence>    
  typename boost::fusion::result_of::as_list<
    typename boost::fusion::result_of::push_front<
    Sequence, 
    typename to_subst_type<T>::type
      >::type
    >::type
  cons(T & e,
       Sequence &seq
       ,typename boost::enable_if<
	 boost::fusion::traits::is_sequence<Sequence> 
	 > ::type*  = 0
       ){ return boost::fusion::push_front<
      Sequence, 
      typename to_subst_type<T>::type
      >(seq, e);}
#endif

  template <typename T>  
  boost::ptr_list<T, boost::view_clone_allocator>
  cons(const T & e,const nil_type & seq){
    boost::ptr_list<T, boost::view_clone_allocator> l;
    l.push_front(const_cast<T* >(&e));    
    return l;}

  template<typename C, typename D> 
  typename uniform_sequence_to_boost_ptr_sequence_view<D>::type   
  cons(C e
       ,const D & d
       ,typename boost::enable_if<boost::mpl::and_<
	 is_subst_copy_object<C>
	 ,is_uniform_sequence_of<D,C>	 
	 > >::type*  = 0            
       ){typename uniform_sequence_to_boost_ptr_sequence_view<D>::type
      l(d.begin(),d.end()); l.push_front(& e); return l;}

  template<typename C, typename D> 
  typename uniform_sequence_to_boost_ptr_sequence_view<D>::type   
  cons(C & e
       ,const D & d
       ,typename boost::enable_if<boost::mpl::and_<
	 is_subst_ref_object<C>
	 ,is_uniform_sequence_of<D,C>	 
	 > >::type* = 0            
       ){typename uniform_sequence_to_boost_ptr_sequence_view<D>::type
      l(d.begin(),d.end()); l.push_front(& e); return l;}


  template<typename T>  std::list<T>
  make_uniform_list(const int n,const T & x)
  {return std::list<T>(n,x);}

  template<typename T>  std::vector<T>
  make_uniform_vector(const int n,const T & x)
  {return std::vector<T>(n,x)  ;}


  template<typename T> const T* cdr(const T l[]){return l+1;}

  template<typename C, typename D> D
  cdr(const std::pair<C,D> & seq){return seq.second;}

  template<typename Seq> 
  typename uniform_sequence_to_boost_ptr_sequence_view<Seq>::type   
  cdr(const Seq & seq
       ,typename boost::enable_if<is_uniform_sequence<Seq> >::type*  = 0 ){ 
    typename Seq::const_iterator i=seq.begin();i++;
    return 
    typename uniform_sequence_to_boost_ptr_sequence_view<Seq>::type(i,seq.end());
  }


  template <typename Sequence>  
  typename Sequence::cdr_type
  //boost::fusion::cons<Sequence>::cdr_type
  cdr( Sequence & seq
       ,typename boost::enable_if<boost::fusion::traits::is_sequence<Sequence> >::type* = 0
       ){return seq.cdr; }

#if 0
  ///////dummy for list_ref
  template <typename Sequence>  Sequence 
  cdr(const Sequence & seq
       ,typename boost::disable_if<boost::mpl::or_<	 
	 boost::fusion::traits::is_sequence<Sequence> 
	 ,is_uniform_sequence<Sequence> > 
	 >::type* = 0
       ){ return seq;}
#endif


  template<typename L, typename T> void
  set_cdr(const L & l, const T & t){&cdr(l)=t;}  


  template<typename T> const T* car_pointer(const T l[]){return l;}
  template<typename C, typename D> const C* car_pointer(const std::pair<C,D> & seq){return &seq.first;}  
  template <typename Sequence>   typename Sequence::const_iterator
  //typename boost::enable_if< is_uniform_sequence<Sequence>,  typename Sequence::iterator>::type 
  car_pointer(const Sequence & seq
	      ,typename boost::enable_if<is_uniform_sequence<Sequence> >::type* = 0 
	      ){return seq.begin();}
  template <typename Sequence>  typename boost::fusion::result_of::begin<Sequence const>::type
  car_pointer(const Sequence & seq
 	      ,typename boost::enable_if<boost::fusion::traits::is_sequence<Sequence> >::type*  = 0            
       ){return boost::fusion::begin(seq);}

  template<typename T> T car(const T l[]){return l[0];}
  template<typename C, typename D> const C car(const std::pair<C,D> & seq){return seq.first;}  
  template <typename Sequence> typename Sequence::iterator::value_type
  car(Sequence & seq
      ,typename boost::enable_if<is_uniform_sequence<Sequence> >::type*  = 0 
      ){return *seq.begin();}
  // A const-reference overload so that temporaries can be passed. ptr_list
  // has value_type T*, so use iterator::value_type as the non-const one does.
  template <typename Sequence> typename Sequence::iterator::value_type
  car(const Sequence & seq
      ,typename boost::enable_if<is_uniform_sequence<Sequence> >::type*  = 0
      ){return *seq.begin();}
  template <typename Sequence>  
  //typename Sequence::car_type
  typename boost::fusion::result_of::value_of<typename boost::fusion::result_of::begin<Sequence const>::type>::type
  car(const Sequence & seq
      ,typename boost::enable_if<boost::fusion::traits::is_sequence<Sequence> >::type*  = 0            
       ){ 
    //return seq.car;
    return boost::fusion::deref(boost::fusion::begin(seq));
  }

#if 0
  ///////dummy for list_ref
  template <typename Sequence>  Sequence 
  car(const Sequence & seq
       ,typename boost::disable_if<boost::mpl::or_<	 
	 boost::fusion::traits::is_sequence<Sequence> 
	 ,is_uniform_sequence<Sequence> > 
	 >::type* = 0
       ){ return seq;}
#endif


  template<typename L, typename T> void
  set_car(const L & l, const T & t){*car_pointer(l)=t;}  

  template<typename T> const T* list_ref_pointer(const T l[] ,int n ){return l+n;}
  template<typename T> T list_ref(const T l[] ,int n ){return l[n];}
  template<typename T> T list_ref(const std::vector<T> & l ,const int &n ){ return l[n];}
  template<typename T> T list_ref(const boost::ptr_vector<T, boost::view_clone_allocator> & l ,const int &n ){ return l[n];}
#if 0
  template <typename Sequence> typename Sequence::iterator
  list_ref_pointer(Sequence & seq,std::size_t n
		   ,typename boost::enable_if<is_uniform_sequence<Sequence> >::type*  = 0){
    typename Sequence ::iterator it  = seq.begin();
    std::advance(it, n);
    return it;}
  template <typename Sequence> typename Sequence::iterator::value_type
  list_ref(Sequence & seq,std::size_t n
	   ,typename boost::enable_if<is_uniform_sequence<Sequence> >::type*  = 0)
  {return *list_ref_pointer(seq,n);}
#else
  template<typename T> 
  typename std::list<T>::const_iterator
  list_ref_pointer(const std::list<T> & l ,const int & n ){
    typename std::list<T>::const_iterator it  = l.begin();
    std::advance(it, n);return it;}
  template<typename T> T
  list_ref(const std::list<T> & l ,const int &n ){
    return *list_ref_pointer(l ,n );}

  template<typename T> 
  typename boost::ptr_list<T, boost::view_clone_allocator>::const_iterator
  list_ref_pointer(const boost::ptr_list<T, boost::view_clone_allocator> & l ,const int & n ){
    typename boost::ptr_list<T, boost::view_clone_allocator>::const_iterator it  = l.begin();
    std::advance(it, n);return it;}
  template<typename T> T
  list_ref(const boost::ptr_list<T, boost::view_clone_allocator> & l ,const int &n ){
    return *list_ref_pointer(l ,n );}

  template<typename T> 
  typename std::vector<T>::const_iterator
  list_ref_pointer(const std::vector<T> & l ,const int & n ){
    typename std::vector<T>::const_iterator it  = l.begin();
    std::advance(it, n);
    return it;}
#endif



#if 0
#if 0
  template <typename Ret,typename Sequence>  Ret
  car_ret_type_chk(const Sequence & seq
		   ,typename boost::enable_if<boost::is_same<Ret, BOOST_TYPEOF_TML(car(seq)) > >::type* = 0
		   ){return car(seq);}
  template <typename Ret,typename Sequence>  Ret
  car_ret_type_chk(const Sequence & seq
		   ,typename boost::disable_if<boost::is_same<Ret, BOOST_TYPEOF_TML(car(seq)) > >::type* = 0
		   ){return Ret();}
#endif

  template <typename Ret,typename Sequence>  Ret
  list_ref(const Sequence & seq, int n
	   //,typename boost::disable_if<boost::fusion::traits::is_sequence<Sequence> >::type*  = 0      
	   ,typename boost::disable_if<boost::mpl::or_<	 
	     boost::fusion::traits::is_sequence<Sequence> 
	     ,is_uniform_sequence<Sequence> > 
				       >::type* = 0
	   ){
    if(n<=0){ return 
	car(seq)
	//car_ret_type_chk<Ret>(seq)
	;}
    else{ return list_ref<Ret>(cdr(seq), n-1);}}
#endif

  template<typename V>
  struct fusion_at_n_functor
  {
    mutable int i;
    int n;
    mutable V value;
    fusion_at_n_functor(int _n):i(0),n(_n){}
    void operator()(const V & t) const
    { if(i==n){value=t;} i++;}  
    template<typename T>
    void operator()(const T & t) const
    { i++;}
  };

  template <typename First,typename Last,typename AtN > void
  list_ref_fusion_impl(First i,Last last,AtN &atn,boost::mpl::true_ ){}
  template <typename First,typename Last,typename AtN > void
  list_ref_fusion_impl(First i,Last last,AtN &atn,boost::mpl::false_ ){
    //std::cout << atn.i << "," <<atn.n << ":" ;    
    if(atn.i == atn.n ){atn(boost::fusion::deref(i));}
    else{
      atn(boost::fusion::deref(i));
      list_ref_fusion_impl(boost::fusion::next(i),last,atn,
			   boost::fusion::result_of::equal_to<
			     typename boost::fusion::result_of::next<First>::type,Last>());}}

  template <typename Ret,typename Sequence>  Ret
  list_ref(Sequence & seq, int n
	   ,typename boost::enable_if<boost::fusion::traits::is_sequence<Sequence> >::type*  = 0            
	   ){ 
    fusion_at_n_functor<Ret> atn(n);
#if 0
    //dbug
    boost::fusion::for_each(seq, atn);
#else
    list_ref_fusion_impl(boost::fusion::begin(seq),boost::fusion::end(seq) ,atn,
			 boost::fusion::result_of::equal_to<
			   typename boost::fusion::result_of::begin<Sequence>::type,
			   typename boost::fusion::result_of::end<Sequence>::type>());    
#endif
    return atn.value;}


#if 1
  //////////////////////////////////
  template <typename Ret,typename C,typename D> Ret
  list_ref(std::pair<C,D> & seq,int n
	   //,typename boost::enable_if<typename boost::mpl::contains <value_types,D>::type >::type* =0
	   ,typename boost::disable_if<boost::mpl::or_<	 
	     is_sequence<D> 
	     ,is_std_pair<D>
	     > >::type* =0		     
	   ){
    if(n<=0){ return 
	car(seq);
    }else{
      return seq.second;
    }}
  //////////////////////////////////

  template <typename Ret,typename C,typename D> Ret
  list_ref(const std::pair<C,D> & seq, int n)
  {
    if(n<=0){ return 
	car(seq)
	;}    
    else{ return list_ref<Ret>(cdr(seq), n-1);}}
#else

  template <typename Ret,typename AtN> void
  list_ref_pair_impl(std::pair<double,double> & seq,AtN &atn
		     ){
    if(atn.i == atn.n ){
      atn(seq.first);
    }
    else{
      atn(seq.second);
    }}


  template <typename Ret,typename C,typename D,typename AtN> void
  list_ref_pair_impl(std::pair<C,D> & seq,AtN &atn
		     //,typename boost::enable_if<typename boost::mpl::contains <value_types,D>::type >::type* =0		     
		     ){
    if(atn.i == atn.n ){
      atn(seq.first);
    }
    else{
      atn(seq.second);
    }}

  template <typename Ret,typename C,typename D,typename AtN> void
  list_ref_pair_impl(std::pair<C,D> & seq,AtN &atn
		     ,typename boost::enable_if<is_sequence<D> >::type* = 0
		     ){
    if(atn.i == atn.n ){
      atn(seq.first);
    }
    else{
      atn(seq.first);
      atn.value=list_ref<Ret>(seq.second,atn.n - atn.i );    
    }}

  template <typename Ret,typename C,typename D,typename AtN> void
  list_ref_pair_impl(std::pair<C,D> & seq,AtN &atn
		     ,typename boost::enable_if<is_std_pair<D> >::type* = 0
		     ){
    if(atn.i == atn.n ){
      atn(seq.first);
    }
    else{
      atn(seq.first);
      list_ref_pair_impl<Ret>(seq.second,atn);
    }}

  template <typename Ret,typename C,typename D> Ret
  list_ref(const std::pair<C,D> & seq, int n)
  {
    fusion_at_n_functor<Ret> atn(n);
    list_ref_pair_impl<Ret>(seq,atn);
    return atn.value;
  }

#endif

#if 0
  template<typename C, typename D>
  std::map<C,D>
  append(const std::pair<C,D> &l1,const std::pair<C,D> &l2)
  {
    std::map<C,D> ll;
    ll.insert(l1);
    ll.insert(l2);
    return ll;
  }
#endif

#if 1
  template<typename Seq> 
  typename uniform_sequence_to_boost_ptr_sequence_view<Seq>::type
  append(const Seq & l1, const Seq & l2
	 ,typename boost::enable_if<is_uniform_sequence<Seq> >::type*  = 0 ){ 
    typedef typename Seq::iterator::value_type value_type;  
    typename Seq::const_reverse_iterator ir=l1.rbegin(); 
    typename uniform_sequence_to_boost_ptr_sequence_view<Seq>::type ll(l2.begin(),l2.end());
    for(std::size_t i=0;i<l1.size();i++){ll.push_front(new value_type(*ir++));}
    return ll;
  }
#else
  template<typename Seq> 
  typename uniform_sequence_to_boost_ptr_sequence_view<Seq>::type
  append(const Seq & l1, const Seq & l2
	 ,typename boost::enable_if<is_uniform_sequence<Seq> >::type*  = 0 ){ 
    Seq ll(l1);
    ll.insert(l1.end(), l2.begin(),l2.end() );
    return ll;
  }
#endif


#if 1
  template<typename Seq1,typename Seq2> 
  boost::fusion::joint_view<Seq1,Seq2>
  append(Seq1 & l1, Seq2 & l2
	 ,typename boost::enable_if<boost::mpl::and_<
	   boost::fusion::traits::is_sequence<Seq1>
	   ,boost::fusion::traits::is_sequence<Seq2> >
	   >::type*  = 0 
	 ){
    Seq1 l1b;
    boost::fusion::copy(l1b,l1);
    boost::fusion::joint_view<Seq1,Seq2> ll(l1b,l2);
    return ll;
  }
#endif


#if 0
  template<typename Seq1,typename Seq2> 
  typename boost::fusion::result_of::as_list<
    typename boost::fusion::result_of::push_back<
      //seq1a_type
      typename boost::fusion::result_of::as_list<  
	typename boost::fusion::result_of::erase<
	  Seq1,
	  typename boost::fusion::result_of::advance<
	    typename boost::fusion::result_of::begin<Seq1>::type,
	    boost::mpl::plus<
	      boost::fusion::result_of::size<Seq1>
	      ,boost::mpl::int_<-1> > >::type
	>::type
	>::type
      ,
      //result_back_type & 
      //Seq2
      BOOST_TYPEOF(cons(boost::fusion::back(Seq1()),Seq2())) &
      //BOOST_TYPEOF(cons(Seq1(),Seq2()))
      >::type
    >::type
  append(Seq1 & seq1, Seq2 & seq2
	 ,typename boost::enable_if<
	   boost::mpl::and_<
	     boost::fusion::traits::is_sequence<Seq1>
	     ,boost::mpl::not_< 
	       boost::fusion::traits::is_sequence<Seq2> > > >::type*  = 0 
	 ){
    //Seq1 ll;boost::fusion::copy(ll,seq1);//Seq1 ll(seq1);
    typedef 
#if 0
      boost::fusion::result_of::as_list<     
      boost::fusion::result_of::erase<
	Seq1,
	boost::fusion::result_of::advance<
	  boost::fusion::result_of::begin<Seq1>::type,
	  boost::mpl::plus< 
	    boost::fusion::result_of::size<Seq1>
	    ,boost::mpl::int_<-1> > >::type
	>::type>::type 
#else
      typename boost::fusion::result_of::as_list<  
	typename boost::fusion::result_of::erase<
	  Seq1,
	  typename boost::fusion::result_of::advance<
	    typename boost::fusion::result_of::begin<Seq1>::type,
	    boost::mpl::plus<
	      boost::fusion::result_of::size<Seq1>
	      ,boost::mpl::int_<-1> > >::type >::type>::type
#endif
	seq1a_type;
    seq1a_type ll(seq1);
    //typedef boost::fusion::result_of::back<Seq1> seq1_back_type;
    //typedef boost::result_of<cons(seq1_back_type,Seq2)>::type result_back_type;
    //BOOST_TYPEOF(cons(boost::fusion::back(seq1),seq2));
    //BOOST_TYPEOF(cons(seq1_back_type(),Seq2()));    
    //boost::type_of
    //boost::fusion::erase(ll, back(vec));
    //boost::fusion::back(ll)=cons(boost::fusion::back(seq1),seq2 );
    return 
      boost::fusion::push_back(ll,cons(boost::fusion::back(seq1),seq2  )  );
  //return ll;
  }
#endif


#if 0
  template<typename Seq1,typename Seq2> 
  appended<Seq1,Seq2>
  append(Seq1 & l1, Seq2 & l2
	 //,typename boost::enable_if<boost::mpl::and_<
	 //boost::fusion::traits::is_sequence<Seq1>
	   //,is_uniform_sequence<Seq2> >
	   //>::type*  = 0 
	 ){
	   return appended<Seq1,Seq2>(l1,l2);
  }
#endif

#if 0
  template<typename Seq>  
  typename uniform_sequence_to_boost_ptr_sequence_view<
    typename Seq::iterator::value_type
    >::type
  //typename Seq::iterator::value_type
  append(Seq & ll
	 ,typename boost::enable_if<
	   boost::mpl::and_<
	     is_uniform_sequence<Seq> 
	     ,is_uniform_sequence<
	       typename Seq::iterator::value_type
	       > >
	   >::type*  = 0
	 )
  {
    //typedef typename Seq::iterator::value_type value_type;  
    typename Seq::const_reverse_iterator ir=ll.rbegin(); 
    typename uniform_sequence_to_boost_ptr_sequence_view<
      typename Seq::iterator::value_type
      >::type
      l((*ir).begin(),(*ir).end());
    ir++;
    for(std::size_t i=1;i<ll.size();i++){
      l=append(*ir++,l);
    }
    return l;
  }
#endif


#if 0
  template<typename T>  
  boost::ptr_list<T, boost::view_clone_allocator>
  append(std::list<T> &l1,std::list<T> &l2)
  {
    boost::ptr_list<T, boost::view_clone_allocator> ll(l2.begin(),l2.end());
    //std::list<T>::const_iterator i
    typename std::list<T>::reverse_iterator ir=l1.rbegin();
    for(int i=0;i<l1.size();i++){
      ll.push_front(
		    //&(*ir++)
		    //*ir++
		    //std::auto_ptr<T>(&(*ir++))
		    new T(*ir++)
		    //ptr_r2lvalue(*ir++)
		    );
    }
    return ll;
  }
#endif


  template<typename Seq> 
  boost::fusion::reverse_view<Seq>
  reverse(Seq & seq
	 ,typename boost::enable_if<boost::fusion::traits::is_sequence<Seq> >::type*  = 0){
    return boost::fusion::reverse(seq) ;
  }


	      
  

  /////////////////////////list end ///////////////////////////////////  






  //template<typename Base>  quoted<Base> quote(Base &base){return quoted<Base>(base); }


  


  typedef std::basic_ofstream<char> stream_type;

  typedef boost::mpl::vector<std::basic_ofstream<char>
			     ,std::streambuf
			     ,std::ostream,std::istream
			     ,std::ifstream,std::ofstream
			     ,std::stringstream
			     ,std::istream,std::ostream
			     ,std::string
			     > stream_types;
   
#if 0   
  typedef boost::mpl::transform< number_string_types,quoted<boost::mpl::_1> >::type quoted_number_string_types ;  
  typedef boost::mpl::insert_range<quoted_number_string_types,
			   boost::mpl::end<quoted_number_string_types>::type,
			   number_string_symbol_types>::type value_types;

 
  typedef boost::mpl::transform< number_types,quoted<boost::mpl::_1> >::type quoted_number_types ;  
  typedef boost::mpl::insert_range<quoted_number_types,
			   boost::mpl::end<quoted_number_types>::type,
			   number_symbol_types>::type scalar_types;

  typedef boost::mpl::vector<char,int,short,long> int_types;
  typedef boost::mpl::transform<int_types, quoted<boost::mpl::_1> >::type quoted_int_types ;  
  typedef boost::mpl::insert_range<quoted_int_types,
			   boost::mpl::end<quoted_int_types>::type,
			   int_types>::type int_quote_types;
#endif
  
  bool is_eq(symbol_type & x, symbol_type & y)  {return x==y;}
  //bool is_eq(string_type & x, string_type & y)  {return (& x)==(& y);}  
  template<typename T>  bool is_eq(T x, T y,typename boost::enable_if<boost::is_integral<T>, T>::type* = 0)  {return x==y;}
  template<typename T>  bool is_eq(quoted<T> &x, quoted<T> &y,typename boost::enable_if<boost::is_integral<T>, T>::type* = 0)      {return x.value==y.value;}
  template<typename T>  bool is_eq(quoted<T> &x, T y,typename boost::enable_if<boost::is_integral<T>, T>::type* = 0)  {return x.value==y;}
  template<typename T>  bool is_eq(T x, quoted<T> &y,typename boost::enable_if<boost::is_integral<T>, T>::type* = 0)  {return x==y.value;}  
  template<typename T>  bool is_eq(T & x, T & y,typename boost::disable_if<typename boost::mpl::contains <int_quote_types,T>::type >::type* =0)  {return (&x)==(&y);}
  template<typename T1,typename T2>  bool is_eq(T1 x, T2 y){return false;}


  //bool is_eqv(string_type & x, string_type & y)  {return x==y;}  
  bool is_eqv(symbol_type & x, symbol_type & y)  {return x==y;}
  bool is_eqv(boost::rational<int> & x, boost::rational<int> & y)  {return x==y;}
  bool is_eqv(quoted<boost::rational<int> > & x, boost::rational<int> & y)  {return x.value==y;}
  bool is_eqv(boost::rational<int>  & x, quoted<boost::rational<int> > & y)  {return x==y.value;}
  bool is_eqv(quoted<boost::rational<int> > & x, quoted<boost::rational<int> > & y)  {return x.value==y.value;}  
  template<typename T> bool is_eqv(T x, T y,typename boost::enable_if<boost::is_arithmetic<T>, T>::type* = 0)  {return x==y;}
  template<typename T> bool is_eqv(quoted<T> &x, quoted<T> &y ,typename boost::enable_if<boost::is_arithmetic<T>, T>::type* = 0)  {return x.value==y.value;}
  template<typename T> bool is_eqv(quoted<T> &x, T y,typename boost::enable_if<boost::is_arithmetic<T>, T>::type* = 0)  {return x.value==y;}
  template<typename T> bool is_eqv(T x, quoted<T> &y,typename boost::enable_if<boost::is_arithmetic<T>, T>::type* = 0)  {return x==y.value;}
  template<typename T> bool is_eqv(T & x, T & y,typename boost::disable_if<typename boost::mpl::contains <scalar_types,T>::type >::type* =0)  {return (&x)==(&y);}
  template<typename T1,typename T2> bool is_eqv(T1 x, T2 y){return false;}


  template<typename T1,typename T2> bool is_equal(const T1 & x, const T2 & y){return false;}
  template<typename T> bool is_equal(const T & x,const T & y){return ( ( x ) == ( y ) );}
  template<typename T> bool is_equal(const quoted<T> &x, const quoted<T> &y) {return is_equal(x.value,y.value);} ////////////
  //template<> bool is_equal(string_type & x, string_type & y)   {return x==y;}
  //template<> bool is_equal(symbol_type & x, symbol_type & y)   {return x==y;}  
  
  // //bool is_equal(quoted<symbol_type> & x, quoted<symbol_type> & y)   {return x.value==y.value;}  
  // template<typename T> bool is_equal(T  x, T  y,typename boost::enable_if<boost::is_arithmetic<T>, T>::type* = 0) {return x==y;}

  // //template<typename T> bool is_equal(T &x, T &y,typename boost::disable_if<boost::is_arithmetic<T>, T>::type* = 0) {return x==y;}
  //template<typename T> bool is_equal(quoted<T> &x, T y,typename boost::enable_if<boost::is_arithmetic<T>, T>::type* = 0) {return x.value==y;}
  //template<typename T> bool is_equal(T x, quoted<T> &y,typename boost::enable_if<boost::is_arithmetic<T>, T>::type* = 0) {return x==y.value;}
  // //template<typename T> bool is_equal(quoted<T> &x, quoted<T> &y,typename boost::enable_if<boost::is_arithmetic<T>, T>::type* = 0) {return x.value==y.value;}
  template<typename T> bool is_equal(const quoted<T> &x,const T & y
   				     ,typename boost::enable_if<typename boost::mpl::contains <
				       //not_c_number_string_types
				       number_string_types
				       ,T>::type >::type* =0)   {return x.value==y;}
  template<typename T> bool is_equal(const T & x,const quoted<T> &y
   				     ,typename boost::enable_if<typename boost::mpl::contains <
				       //not_c_number_string_types
				       number_string_types
				       ,T>::type >::type* =0)  {return x==y.value;}
  // // template<typename T> bool is_equal(quoted<T> & x, quoted<T> &y
  // // 				     ,typename boost::enable_if<typename boost::mpl::contains <not_c_number_string_types,T>::type >::type* =0)  {return x.value==y.value;}


  // // template<typename T> bool is_equal(quoted<T> &x, quoted<T> &y
  // // 				     ,typename boost::disable_if<typename boost::mpl::contains <value_types,T>::type >::type* =0)
  // // {return is_equal(x.value,y.value);} 
  // // template<typename T> bool is_equal(T &x, quoted<T> &y
  // // 				     ,typename boost::disable_if<typename boost::mpl::contains <value_types,T>::type >::type* =0)
  // // {return is_equal(x,y.value);} 

  // // template<typename T> bool is_equal(quoted<T> &x, T &y
  // // 				     ,typename boost::disable_if<typename boost::mpl::contains <value_types,T>::type >::type* =0)
  // // {return is_equal(x.value,y);} 
  // // template<typename T1,typename T2> bool is_equal(quoted<T1> &x, quoted<T2> &y
  // // 				     ,typename boost::disable_if<typename boost::mpl::contains <value_types,T1>::type >::type* =0
  // // 				     ,typename boost::disable_if<typename boost::mpl::contains <value_types,T2>::type >::type* =0
  // // 						  )
  // // {return is_equal(x.value,y.value);}
  // template<typename T> bool is_equal(T & x, T & y
  // 				     ,typename boost::disable_if<typename boost::mpl::contains <value_types,T>::type >::type* =0)  
  // {return x==y;}
  // 				       //number_string_symbol_types




  ///////variant shrink  begin

  //typedef boost::mpl::vector<int,boost::rational<int>,float,double,long double,std::complex<double> >::type scheme_ordered_number_types;
  //typedef scheme_ordered_number_types ordered_number_types;
  typedef boost::mpl::vector<int,boost::rational<int>,float,double,std::complex<double>  >::type default_type_order;



////////////mpl general util begin

template<typename TypeVec>
struct is_mpl_sequence_single : 
  boost::is_same<
  typename boost::mpl::size<TypeVec>::type
  ,typename boost::mpl::long_<1> >
 {};

template<typename TypeVec>
struct mpl_sequence_if_single_then_element_else_variant : public
  boost::mpl::if_<
  typename is_mpl_sequence_single<TypeVec>::type
  ,
  typename 
  boost::mpl::front<TypeVec>//::type
  //,typename TypeVec::type
  //,TypeVec
  ,typename boost::make_variant_over<TypeVec>
  >::type
{};

  template<typename TypeVec,typename IsLess>
  struct max_in_mpl_sequence_given_is_less_lambda : public 
  boost::mpl::fold<
    TypeVec
    ,typename boost::mpl::front<TypeVec>::type
    ,boost::mpl::if_<
       boost::mpl::bind2<IsLess,boost::mpl::_1 , boost::mpl::_2 >
       //typename boost::mpl::apply<IsLess,boost::mpl::_1 , boost::mpl::_2 >//::type
       //typename IsLess::apply< boost::mpl::_1 , boost::mpl::_2 >
       //boost::mpl::true_
       ,boost::mpl::_2 , boost::mpl::_1 >
    >
  {};


  template<typename TypeVec,typename TypeOrder>
  struct mpl_vector_contains_filter : boost::mpl::filter_view<
    TypeVec
    ,boost::mpl::contains<TypeOrder,boost::mpl::_1>
    >
  {};

  template<typename TypeVec,typename TypeOrder>
  struct mpl_vector_not_contains_filter : boost::mpl::filter_view<
    TypeVec
    ,boost::mpl::not_<boost::mpl::contains<TypeOrder,boost::mpl::_1> >
    >
  {};



////////////mpl general util end



   template<typename T1,typename T2,typename TypeOrder>
   struct is_less_in_orderd_mpl_sequence :
     boost::is_same <
     typename boost::mpl::find<      
      typename  boost::mpl::iterator_range<
	typename boost::mpl::find<TypeOrder,T2>::type , 
	typename boost::mpl::end<TypeOrder>::type
	>::type , 
      T1 >::type, 
    typename boost::mpl::end<TypeOrder>::type >
  {};

  typedef boost::mpl::lambda<is_less_in_orderd_mpl_sequence<boost::mpl::_1 , boost::mpl::_2 , default_type_order> >::type is_less_over_default_type_order_mpl_lambda;


  template<typename T1,typename TBase,typename TypeOrder>
   struct is_generalizable_to_using_generaize_order_sequence :
     boost::mpl::if_<
     typename 
     boost::mpl::contains<TypeOrder,T1>::type
     ,
     typename
     boost::mpl::if_<
	typename 
	boost::mpl::contains<TypeOrder,TBase>::type
	,
	//typename 
	is_less_in_orderd_mpl_sequence<T1,TBase,TypeOrder> //::type
	,
	//typename 
	boost::mpl::false_ //::type 
	>::type
     ,
     //typename 
     boost::mpl::false_ //::type 
     > ::type
  {};

template<typename TypeOrder>
struct generate_mpl_lambda_is_generalizable_to_from_type_order_sequence
{ typedef typename boost::mpl::lambda<is_generalizable_to_using_generaize_order_sequence<boost::mpl::_1 , boost::mpl::_2 , TypeOrder> >::type type;
};

//typedef boost::mpl::lambda<is_generalizable_to_using_generaize_order_sequence<boost::mpl::_1 , boost::mpl::_2 , default_type_order> >::type is_generalizable_using_default_type_order_mpl_lambda;

typedef generate_mpl_lambda_is_generalizable_to_from_type_order_sequence<default_type_order>::type is_generalizable_using_default_type_order_mpl_lambda;


//template<typename TypeVec,typename Greater>
template<typename TypeVec,typename TypeBase,typename IsGeneralizable>
  struct generalize_type_sequence_to_base : 
  boost::mpl::transform<
    TypeVec
    ,boost::mpl::if_<
       boost::mpl::bind2<IsGeneralizable,boost::mpl::_1 , TypeBase >
       ,TypeBase
       ,boost::mpl::_1>
   >
  {};


template<typename TypeVec,typename IsGeneralizable>
struct generaize_type_sequence_using_is_generalizable_to : 
  boost::mpl::fold<
  TypeVec
  ,TypeVec
  ,
  //typename 
  generalize_type_sequence_to_base<boost::mpl::_1,boost::mpl::_2,IsGeneralizable > //::type
  >::type
{};

  
template<typename TypeVec,typename IsGeneralizable=is_generalizable_using_default_type_order_mpl_lambda >
struct make_variant_shrink_over : public
//mpl_sequence_if_single_to_element
mpl_sequence_if_single_then_element_else_variant<
  typename 
  boost::mpl::unique<
    typename 
    generaize_type_sequence_using_is_generalizable_to<TypeVec,IsGeneralizable>::type
    ,boost::is_same<boost::mpl::_1,boost::mpl::_2>
    >::type
  >//::type
  {};



template < BOOST_VARIANT_ENUM_PARAMS(typename T) >
typename max_in_mpl_sequence_given_is_less_lambda<
  typename 
  boost::variant< BOOST_VARIANT_ENUM_PARAMS(T) >::types
  ,is_generalizable_using_default_type_order_mpl_lambda>::type 
get_number(boost::variant< BOOST_VARIANT_ENUM_PARAMS(T) >& x)
{
  return boost::get<
    typename max_in_mpl_sequence_given_is_less_lambda<
      typename 
      boost::variant< BOOST_VARIANT_ENUM_PARAMS(T) >::types
      ,is_generalizable_using_default_type_order_mpl_lambda>::type
    >(x);  
}



template<typename T>
T & get_number(boost::optional<T &> x) {  return *x;}

template<typename T>
T & get_number(boost::optional<const T &> x) {  return *x;}


template<typename T>
T  get_number(boost::optional<T > x) {  return *x;}

template<typename T>
T get_number(T x)
{ 
  return x;
}



template<typename T> boost::optional<T &> 
optional_attach(T &x) { boost::optional<T &> y(x); return y; }

template<typename T> boost::optional<T &>  
optional_attach(const T &x) 
{ boost::optional<T &> y(const_cast<T &>(x)); return y; }





  // template<typename Seq,typename X>
  // struct mpl_adjoin_copy_vector : public 
  // boost::mpl::fold<
  //   //typename TypeVec::type ,
  //   Seq ,
  //   //typename Seq::type ,
  //   boost::mpl::vector1<X> ,
  //   //boost::mpl::insert<boost::mpl::_1,boost::mpl::_2>
  //   boost::mpl::push_back<boost::mpl::_1,boost::mpl::_2> //::type
  //   //boost::mpl::push_front<boost::mpl::_1 , boost::mpl::_2 >
  //   >
  // {};


  ///////variant shrink end








#if CONSED_AS_STD_PAIR
#undef consd
#endif

  
  
}


//template<class T>void Func(T arg1, typename ::boost::enable_if_c< ::boost::is_same<T, int>::value >::type* =0) { ... }

//template<class T>void Func(T arg1, typename ::boost::enable_if_c< ::boost::is_same<T, string>::value >::type* =0) { ... }

template<typename F,typename ResultType>
  struct promise
  {
    //need partial specialization or enable_if    
    //typedef typename boost::function_types::result_type<F>::type result_type;
    //typedef typename F::result_type result_type;    
    typedef ResultType result_type;
    result_type result;
    bool is_evaled;    
    F f;
    promise(F & _f):f(_f),is_evaled(false){}
    result_type operator()(){ 
      if(is_evaled)
	return result;
      else{	
	result=f();
	is_evaled=true;	
	return result;
      }}
};




#ifdef BOOST_NO_DECLTYPE

template<typename F> promise<F,typename boost::function_types::result_type<F>::type> make_promise(F &f){  return promise<F,typename boost::function_types::result_type<F>::type>(f);}
template<typename ResultType,typename F> promise<F,ResultType> make_promise(F f){  return promise<F,ResultType>(f);}
#else

template<typename F> auto make_promise(F f) -> promise<F,decltype(f())>{return promise<F,decltype(f())>(f);}

#endif

template<typename F> promise<boost::function<F>,typename boost::function<F>::result_type> make_promise(boost::function<F> &f){  return promise<boost::function<F>,typename boost::function<F>::result_type>(f);}


#ifdef BOOST_NO_DECLTYPE
#else
template<typename PromiseType>
auto force(PromiseType promise) -> decltype(promise())
{
  return promise();
}
#endif

//////////////////////////////////////////////////////////////////////////
// Delayed streams as a nominal type whose recursion is erased through
// std::function. Expanding the type structurally yields an infinite type and
// the occurs check rejects it; naming it lets unification compare element
// types in a single step, so inference terminates.
namespace scm2cpp {

  template<typename T> struct stream_cell {
    typedef T value_type;
    T head;
    std::function<stream_cell<T>()> tail;
    stream_cell(){}
    stream_cell(const T& h, const std::function<stream_cell<T>()>& t)
      : head(h), tail(t) {}
  };

  // Corresponds to (cons a (delay b)); wraps b without evaluating it.
  template<typename T, typename F>
  stream_cell<T> make_stream(const T& h, F f) {
    return stream_cell<T>(h, std::function<stream_cell<T>()>(f));
  }

  template<typename T> T car(const stream_cell<T>& s) { return s.head; }
  template<typename T> std::function<stream_cell<T>()> cdr(const stream_cell<T>& s) { return s.tail; }

}

//////////////////////////////////////////////////////////////////////////
// An n-dimensional summed-area table.  Built once over a flat row-major
// array, it answers the sum over any axis-aligned box in O(2^n) additions
// by inclusion-exclusion, instead of O(volume) by looping.  The table is a
// representation an inferencer may choose for an array whose only reads
// are box sums; the choice is valid only if every write precedes the
// first query, which build() makes explicit.
namespace scm2cpp {

  template<typename T, int N> struct integral_image {
    std::vector<T> table;      // padded with a zero border: dim[k]+1 per axis
    int dim[N];                // extents of the source array
    int stride[N];             // strides of the padded table, innermost last

    integral_image() { for (int k = 0; k < N; ++k) { dim[k] = 0; stride[k] = 0; } }

    // src is the flat row-major source; dims its extents, slowest axis first.
    template<typename Src>
    void build(const Src& src, const int (&dims)[N]) {
      std::size_t total = 1;
      for (int k = N; k-- > 0; ) {
        dim[k] = dims[k];
        stride[k] = int(total);
        total *= std::size_t(dims[k] + 1);
      }
      table.assign(total, T(0));
      // Fill: table[i0+1,..] = src[i0,..], then prefix-sum along each axis.
      std::size_t count = 1;
      for (int k = 0; k < N; ++k) count *= std::size_t(dim[k]);
      for (std::size_t s = 0; s < count; ++s) {
        std::size_t rem = s, t = 0;
        for (int k = N; k-- > 0; ) {
          int i = int(rem % std::size_t(dim[k])); rem /= std::size_t(dim[k]);
          t += std::size_t(i + 1) * std::size_t(stride[k]);
        }
        table[t] = src[s];
      }
      for (int k = 0; k < N; ++k)
        for (std::size_t t = 0; t < total; ++t)
          if (int(t / std::size_t(stride[k])) % (dim[k] + 1) != 0)
            table[t] += table[t - std::size_t(stride[k])];
    }

    // Sum of the source over the closed box [lo[k], hi[k]] on every axis.
    T query(const int (&lo)[N], const int (&hi)[N]) const {
      T acc = T(0);
      for (unsigned corner = 0; corner < (1u << N); ++corner) {
        std::size_t t = 0; int sign = 1;
        for (int k = 0; k < N; ++k) {
          int edge = (corner >> k) & 1 ? lo[k] : hi[k] + 1;   // 0..dim[k]
          if ((corner >> k) & 1) sign = -sign;
          t += std::size_t(edge) * std::size_t(stride[k]);
        }
        acc += sign > 0 ? table[t] : T(0) - table[t];
      }
      return acc;
    }

    // The two-dimensional case, spelled out for the generated code.
    T query2(int i0, int i1, int j0, int j1) const {
      const int lo[2] = { i0, j0 }, hi[2] = { i1, j1 };
      return query(lo, hi);
    }
  };

  // (integral-image v n m) in the generated code: build a rank-2 table.
  template<typename T, typename Src>
  integral_image<T,2> make_integral_image2(const Src& src, int n, int m) {
    integral_image<T,2> ii;
    const int dims[2] = { n, m };
    ii.build(src, dims);
    return ii;
  }

}

#endif

//Copyright (C) 2011-2026  Hirotaka Niitsuma
//
//This header is part of Scm2Cpp and is distributed under the MIT License.
//See the LICENSE file in the project root for the full text.
//
//Note: this header is included into the C++ that Scm2Cpp generates, and so
//becomes part of the user's program. The MIT terms were chosen so that this
//imposes no obligation on that program beyond preserving this notice.
