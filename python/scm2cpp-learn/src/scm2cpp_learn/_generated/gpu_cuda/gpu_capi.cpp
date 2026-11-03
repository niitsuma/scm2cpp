// extern "C" wrappers over the translated functions, for Python and
// any other caller that speaks the C ABI. Array parameters arrive as
// element pointers: a view parameter takes the pointer as it is, so
// the caller's buffer is read and written in place with no copy; a
// fixed-extent one is reinterpreted as the std::array the function
// expects. The caller guarantees the length either way.
// Build (boost includes only if the generated header asks for them,
// which a numeric kernel's does not):
//   g++ -O2 -std=c++17 -shared -fPIC -I. -o libgpu.so gpu_capi.cpp
#include "gpu.hpp"
#include <vector>
#include <algorithm>

extern "C" double scm2cpp_eig_hypot(double a, double b) {
  double scm2cpp_r = eig_hypot(a, b);
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" std::int64_t scm2cpp_sym_eigen(double* a, std::int64_t a_len, double* v, std::int64_t v_len, double* ev, std::int64_t ev_len, double* e, std::int64_t e_len, std::int64_t m) {
  std::int64_t scm2cpp_r = sym_eigen(scm2cpp::span<double>(a, a_len), scm2cpp::span<double>(v, v_len), scm2cpp::span<double>(ev, ev_len), scm2cpp::span<double>(e, e_len), m);
  { scm2cpp::span<double> s(a, a_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(v, v_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(ev, ev_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(e, e_len); scm2cpp::cu::need_host(s); }
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" double scm2cpp_eig_abs(double a) {
  double scm2cpp_r = eig_abs(a);
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" std::int64_t scm2cpp_eig_order(double* ev, std::int64_t ev_len, int* ord, std::int64_t ord_len, std::int64_t m) {
  std::int64_t scm2cpp_r = eig_order(scm2cpp::span<double>(ev, ev_len), scm2cpp::span<int>(ord, ord_len), m);
  { scm2cpp::span<double> s(ev, ev_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<int> s(ord, ord_len); scm2cpp::cu::need_host(s); }
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" std::int64_t scm2cpp_sym_eigen_top(double* a, std::int64_t a_len, double* v, std::int64_t v_len, double* ev, std::int64_t ev_len, double* e, std::int64_t e_len, std::int64_t m, std::int64_t k) {
  std::int64_t scm2cpp_r = sym_eigen_top(scm2cpp::span<double>(a, a_len), scm2cpp::span<double>(v, v_len), scm2cpp::span<double>(ev, ev_len), scm2cpp::span<double>(e, e_len), m, k);
  { scm2cpp::span<double> s(a, a_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(v, v_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(ev, ev_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(e, e_len); scm2cpp::cu::need_host(s); }
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" std::int64_t scm2cpp_sym_eigen_gen(double* a, std::int64_t a_len, double* b, std::int64_t b_len, double* v, std::int64_t v_len, double* ev, std::int64_t ev_len, double* e, std::int64_t e_len, std::int64_t m) {
  std::int64_t scm2cpp_r = sym_eigen_gen(scm2cpp::span<double>(a, a_len), scm2cpp::span<double>(b, b_len), scm2cpp::span<double>(v, v_len), scm2cpp::span<double>(ev, ev_len), scm2cpp::span<double>(e, e_len), m);
  { scm2cpp::span<double> s(a, a_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(b, b_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(v, v_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(ev, ev_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(e, e_len); scm2cpp::cu::need_host(s); }
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" double scm2cpp_ica_tanh(double x) {
  double scm2cpp_r = ica_tanh(x);
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" std::int64_t scm2cpp_ica_sym(double* w, std::int64_t w_len, double* a, std::int64_t a_len, double* v, std::int64_t v_len, double* ev, std::int64_t ev_len, double* e, std::int64_t e_len, double* t, std::int64_t t_len, std::int64_t m) {
  std::int64_t scm2cpp_r = ica_sym(scm2cpp::span<double>(w, w_len), scm2cpp::span<double>(a, a_len), scm2cpp::span<double>(v, v_len), scm2cpp::span<double>(ev, ev_len), scm2cpp::span<double>(e, e_len), scm2cpp::span<double>(t, t_len), m);
  { scm2cpp::span<double> s(w, w_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(a, a_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(v, v_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(ev, ev_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(e, e_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(t, t_len); scm2cpp::cu::need_host(s); }
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" std::int64_t scm2cpp_fastica(double* x, std::int64_t x_len, double* winit, std::int64_t winit_len, double* comps, std::int64_t comps_len, double* white, std::int64_t white_len, double* unmix, std::int64_t unmix_len, double* mean, std::int64_t mean_len, std::int64_t maxiter, double tol, std::int64_t n, std::int64_t p, std::int64_t nc) {
  std::int64_t scm2cpp_r = fastica(scm2cpp::span<double>(x, x_len), scm2cpp::span<double>(winit, winit_len), scm2cpp::span<double>(comps, comps_len), scm2cpp::span<double>(white, white_len), scm2cpp::span<double>(unmix, unmix_len), scm2cpp::span<double>(mean, mean_len), maxiter, tol, n, p, nc);
  { scm2cpp::span<double> s(x, x_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(winit, winit_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(comps, comps_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(white, white_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(unmix, unmix_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(mean, mean_len); scm2cpp::cu::need_host(s); }
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" std::int64_t scm2cpp_gmm_mstep(double* x, std::int64_t x_len, double* resp, std::int64_t resp_len, double* weights, std::int64_t weights_len, double* means, std::int64_t means_len, double* prec, std::int64_t prec_len, double* dw, std::int64_t dw_len, double* cov, std::int64_t cov_len, double* l, std::int64_t l_len, double* u, std::int64_t u_len, double reg, std::int64_t norm, std::int64_t n, std::int64_t p, std::int64_t kc) {
  std::int64_t scm2cpp_r = gmm_mstep(scm2cpp::span<double>(x, x_len), scm2cpp::span<double>(resp, resp_len), scm2cpp::span<double>(weights, weights_len), scm2cpp::span<double>(means, means_len), scm2cpp::span<double>(prec, prec_len), scm2cpp::span<double>(dw, dw_len), scm2cpp::span<double>(cov, cov_len), scm2cpp::span<double>(l, l_len), scm2cpp::span<double>(u, u_len), reg, norm, n, p, kc);
  { scm2cpp::span<double> s(x, x_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(resp, resp_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(weights, weights_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(means, means_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(prec, prec_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(dw, dw_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(cov, cov_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(l, l_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(u, u_len); scm2cpp::cu::need_host(s); }
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" double scm2cpp_gmm_estep(double* x, std::int64_t x_len, double* resp, std::int64_t resp_len, double* weights, std::int64_t weights_len, double* means, std::int64_t means_len, double* prec, std::int64_t prec_len, double* wlp, std::int64_t wlp_len, double* y, std::int64_t y_len, double* u, std::int64_t u_len, double* mu, std::int64_t mu_len, std::int64_t n, std::int64_t p, std::int64_t kc) {
  double scm2cpp_r = gmm_estep(scm2cpp::span<double>(x, x_len), scm2cpp::span<double>(resp, resp_len), scm2cpp::span<double>(weights, weights_len), scm2cpp::span<double>(means, means_len), scm2cpp::span<double>(prec, prec_len), scm2cpp::span<double>(wlp, wlp_len), scm2cpp::span<double>(y, y_len), scm2cpp::span<double>(u, u_len), scm2cpp::span<double>(mu, mu_len), n, p, kc);
  { scm2cpp::span<double> s(x, x_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(resp, resp_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(weights, weights_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(means, means_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(prec, prec_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(wlp, wlp_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(y, y_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(u, u_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(mu, mu_len); scm2cpp::cu::need_host(s); }
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" double scm2cpp_gmm_abs(double a) {
  double scm2cpp_r = gmm_abs(a);
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" std::int64_t scm2cpp_gmm(double* x, std::int64_t x_len, double* resp, std::int64_t resp_len, double* weights, std::int64_t weights_len, double* means, std::int64_t means_len, double* prec, std::int64_t prec_len, double* labels, std::int64_t labels_len, double* out, std::int64_t out_len, std::int64_t maxiter, double tol, double reg, std::int64_t n, std::int64_t p, std::int64_t kc) {
  std::int64_t scm2cpp_r = gmm(scm2cpp::span<double>(x, x_len), scm2cpp::span<double>(resp, resp_len), scm2cpp::span<double>(weights, weights_len), scm2cpp::span<double>(means, means_len), scm2cpp::span<double>(prec, prec_len), scm2cpp::span<double>(labels, labels_len), scm2cpp::span<double>(out, out_len), maxiter, tol, reg, n, p, kc);
  { scm2cpp::span<double> s(x, x_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(resp, resp_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(weights, weights_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(means, means_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(prec, prec_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(labels, labels_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(out, out_len); scm2cpp::cu::need_host(s); }
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" double scm2cpp_logistic_fg(double* coef, std::int64_t coef_len, double* g, std::int64_t g_len, double* x, std::int64_t x_len, double* y, std::int64_t y_len, double* z, std::int64_t z_len, double l2, std::int64_t multi, std::int64_t fitint, std::int64_t n, std::int64_t p, std::int64_t k) {
  double scm2cpp_r = logistic_fg(scm2cpp::span<double>(coef, coef_len), scm2cpp::span<double>(g, g_len), scm2cpp::span<double>(x, x_len), scm2cpp::span<double>(y, y_len), scm2cpp::span<double>(z, z_len), l2, multi, fitint, n, p, k);
  { scm2cpp::span<double> s(coef, coef_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(g, g_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(x, x_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(y, y_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(z, z_len); scm2cpp::cu::need_host(s); }
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" std::int64_t scm2cpp_logistic_lbfgs(double* x, std::int64_t x_len, double* y, std::int64_t y_len, double* coef, std::int64_t coef_len, double* out, std::int64_t out_len, double c, std::int64_t maxiter, double tol, std::int64_t multi, std::int64_t fitint, std::int64_t n, std::int64_t p, std::int64_t k) {
  std::int64_t scm2cpp_r = logistic_lbfgs(scm2cpp::span<double>(x, x_len), scm2cpp::span<double>(y, y_len), scm2cpp::span<double>(coef, coef_len), scm2cpp::span<double>(out, out_len), c, maxiter, tol, multi, fitint, n, p, k);
  { scm2cpp::span<double> s(x, x_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(y, y_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(coef, coef_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(out, out_len); scm2cpp::cu::need_host(s); }
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" double scm2cpp_huber_fg(double* coef, std::int64_t coef_len, double* g, std::int64_t g_len, double* x, std::int64_t x_len, double* y, std::int64_t y_len, double* z, std::int64_t z_len, double epsilon, double alpha, std::int64_t fitint, std::int64_t n, std::int64_t p) {
  double scm2cpp_r = huber_fg(scm2cpp::span<double>(coef, coef_len), scm2cpp::span<double>(g, g_len), scm2cpp::span<double>(x, x_len), scm2cpp::span<double>(y, y_len), scm2cpp::span<double>(z, z_len), epsilon, alpha, fitint, n, p);
  { scm2cpp::span<double> s(coef, coef_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(g, g_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(x, x_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(y, y_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(z, z_len); scm2cpp::cu::need_host(s); }
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" std::int64_t scm2cpp_huber(double* x, std::int64_t x_len, double* y, std::int64_t y_len, double* coef, std::int64_t coef_len, double* out, std::int64_t out_len, double epsilon, double alpha, std::int64_t maxiter, double tol, std::int64_t fitint, std::int64_t n, std::int64_t p) {
  std::int64_t scm2cpp_r = huber(scm2cpp::span<double>(x, x_len), scm2cpp::span<double>(y, y_len), scm2cpp::span<double>(coef, coef_len), scm2cpp::span<double>(out, out_len), epsilon, alpha, maxiter, tol, fitint, n, p);
  { scm2cpp::span<double> s(x, x_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(y, y_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(coef, coef_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(out, out_len); scm2cpp::cu::need_host(s); }
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" double scm2cpp_glm_fg(double* coef, std::int64_t coef_len, double* g, std::int64_t g_len, double* x, std::int64_t x_len, double* y, std::int64_t y_len, double* z, std::int64_t z_len, std::int64_t family, double power, double l2, std::int64_t fitint, std::int64_t n, std::int64_t p) {
  double scm2cpp_r = glm_fg(scm2cpp::span<double>(coef, coef_len), scm2cpp::span<double>(g, g_len), scm2cpp::span<double>(x, x_len), scm2cpp::span<double>(y, y_len), scm2cpp::span<double>(z, z_len), family, power, l2, fitint, n, p);
  { scm2cpp::span<double> s(coef, coef_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(g, g_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(x, x_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(y, y_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(z, z_len); scm2cpp::cu::need_host(s); }
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" std::int64_t scm2cpp_glm(double* x, std::int64_t x_len, double* y, std::int64_t y_len, double* coef, std::int64_t coef_len, double* out, std::int64_t out_len, std::int64_t family, double power, double alpha, std::int64_t maxiter, double tol, std::int64_t fitint, std::int64_t n, std::int64_t p) {
  std::int64_t scm2cpp_r = glm(scm2cpp::span<double>(x, x_len), scm2cpp::span<double>(y, y_len), scm2cpp::span<double>(coef, coef_len), scm2cpp::span<double>(out, out_len), family, power, alpha, maxiter, tol, fitint, n, p);
  { scm2cpp::span<double> s(x, x_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(y, y_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(coef, coef_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(out, out_len); scm2cpp::cu::need_host(s); }
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" double scm2cpp_lb_abs(double a) {
  double scm2cpp_r = lb_abs(a);
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" double scm2cpp_lb_max(double a, double b) {
  double scm2cpp_r = lb_max(a, b);
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" double scm2cpp_lb_min(double a, double b) {
  double scm2cpp_r = lb_min(a, b);
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" std::int64_t scm2cpp_lb_dcstep(double* cs, double fp, double dp, double stpmin, double stpmax) {
  std::int64_t scm2cpp_r = lb_dcstep(*reinterpret_cast<std::array<double,8>*>(cs), fp, dp, stpmin, stpmax);
  { scm2cpp::span<double> s(cs, 8); scm2cpp::cu::need_host(s); }
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" std::int64_t scm2cpp_lb_search_start(double* ls, double f, double g, double stp, double stpmin, double stpmax, double ftol) {
  std::int64_t scm2cpp_r = lb_search_start(*reinterpret_cast<std::array<double,16>*>(ls), f, g, stp, stpmin, stpmax, ftol);
  { scm2cpp::span<double> s(ls, 16); scm2cpp::cu::need_host(s); }
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" std::int64_t scm2cpp_lb_search_step(double* ls, double* cs, double f, double g, double ftol, double gtol, double xtol, double stpmin, double stpmax) {
  std::int64_t scm2cpp_r = lb_search_step(*reinterpret_cast<std::array<double,16>*>(ls), *reinterpret_cast<std::array<double,8>*>(cs), f, g, ftol, gtol, xtol, stpmin, stpmax);
  { scm2cpp::span<double> s(ls, 16); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(cs, 8); scm2cpp::cu::need_host(s); }
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" double scm2cpp_lb_dot(double* a, std::int64_t a_len, double* b, std::int64_t b_len, std::int64_t nv) {
  double scm2cpp_r = lb_dot(scm2cpp::span<double>(a, a_len), scm2cpp::span<double>(b, b_len), nv);
  { scm2cpp::span<double> s(a, a_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(b, b_len); scm2cpp::cu::need_host(s); }
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" double scm2cpp_lb_dot_row(double* mem, std::int64_t mem_len, std::int64_t slot, double* v, std::int64_t v_len, std::int64_t nv) {
  double scm2cpp_r = lb_dot_row(scm2cpp::span<double>(mem, mem_len), slot, scm2cpp::span<double>(v, v_len), nv);
  { scm2cpp::span<double> s(mem, mem_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(v, v_len); scm2cpp::cu::need_host(s); }
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" double scm2cpp_lb_dot_rows(double* a, std::int64_t a_len, std::int64_t ra, double* b, std::int64_t b_len, std::int64_t rb, std::int64_t nv) {
  double scm2cpp_r = lb_dot_rows(scm2cpp::span<double>(a, a_len), ra, scm2cpp::span<double>(b, b_len), rb, nv);
  { scm2cpp::span<double> s(a, a_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(b, b_len); scm2cpp::cu::need_host(s); }
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" double scm2cpp_lb_projgr(double* g, std::int64_t g_len, double* w, std::int64_t w_len, std::int64_t ib, double lbv, std::int64_t nv) {
  double scm2cpp_r = lb_projgr(scm2cpp::span<double>(g, g_len), scm2cpp::span<double>(w, w_len), ib, lbv, nv);
  { scm2cpp::span<double> s(g, g_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(w, w_len); scm2cpp::cu::need_host(s); }
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" std::int64_t scm2cpp_lb_hv(double* q, std::int64_t q_len, double* smem, std::int64_t smem_len, double* ymem, std::int64_t ymem_len, double* rho, std::int64_t rho_len, double* al, std::int64_t al_len, double theta, std::int64_t col, std::int64_t head, std::int64_t m, std::int64_t nv) {
  std::int64_t scm2cpp_r = lb_hv(scm2cpp::span<double>(q, q_len), scm2cpp::span<double>(smem, smem_len), scm2cpp::span<double>(ymem, ymem_len), scm2cpp::span<double>(rho, rho_len), scm2cpp::span<double>(al, al_len), theta, col, head, m, nv);
  { scm2cpp::span<double> s(q, q_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(smem, smem_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(ymem, ymem_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(rho, rho_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(al, al_len); scm2cpp::cu::need_host(s); }
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" double scm2cpp_lb_vbv(double* v, std::int64_t v_len, double* smem, std::int64_t smem_len, double* ymem, std::int64_t ymem_len, double* rho, std::int64_t rho_len, double* bm, std::int64_t bm_len, double* sb, std::int64_t sb_len, double theta, std::int64_t col, std::int64_t head, std::int64_t m, std::int64_t nv) {
  double scm2cpp_r = lb_vbv(scm2cpp::span<double>(v, v_len), scm2cpp::span<double>(smem, smem_len), scm2cpp::span<double>(ymem, ymem_len), scm2cpp::span<double>(rho, rho_len), scm2cpp::span<double>(bm, bm_len), scm2cpp::span<double>(sb, sb_len), theta, col, head, m, nv);
  { scm2cpp::span<double> s(v, v_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(smem, smem_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(ymem, ymem_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(rho, rho_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(bm, bm_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(sb, sb_len); scm2cpp::cu::need_host(s); }
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" std::int64_t scm2cpp_lb_direction(double* w, std::int64_t w_len, double* g, std::int64_t g_len, double* d, std::int64_t d_len, double* q, std::int64_t q_len, double* e, std::int64_t e_len, double* smem, std::int64_t smem_len, double* ymem, std::int64_t ymem_len, double* rho, std::int64_t rho_len, double* al, std::int64_t al_len, double* bm, std::int64_t bm_len, double* sb, std::int64_t sb_len, double theta, std::int64_t col, std::int64_t head, std::int64_t m, std::int64_t ib, double lbv, std::int64_t nv) {
  std::int64_t scm2cpp_r = lb_direction(scm2cpp::span<double>(w, w_len), scm2cpp::span<double>(g, g_len), scm2cpp::span<double>(d, d_len), scm2cpp::span<double>(q, q_len), scm2cpp::span<double>(e, e_len), scm2cpp::span<double>(smem, smem_len), scm2cpp::span<double>(ymem, ymem_len), scm2cpp::span<double>(rho, rho_len), scm2cpp::span<double>(al, al_len), scm2cpp::span<double>(bm, bm_len), scm2cpp::span<double>(sb, sb_len), theta, col, head, m, ib, lbv, nv);
  { scm2cpp::span<double> s(w, w_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(g, g_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(d, d_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(q, q_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(e, e_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(smem, smem_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(ymem, ymem_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(rho, rho_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(al, al_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(bm, bm_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(sb, sb_len); scm2cpp::cu::need_host(s); }
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" std::int64_t scm2cpp_lbfgs(std::int64_t kind, double* w, std::int64_t w_len, double* x, std::int64_t x_len, double* y, std::int64_t y_len, double* aux, double* work, std::int64_t work_len, double* out, std::int64_t out_len, std::int64_t m, std::int64_t maxiter, double pgtol, double ftol, std::int64_t maxls, std::int64_t ib, double lbv, std::int64_t nv, std::int64_t n, std::int64_t p, std::int64_t k) {
  std::int64_t scm2cpp_r = lbfgs(kind, scm2cpp::span<double>(w, w_len), scm2cpp::span<double>(x, x_len), scm2cpp::span<double>(y, y_len), *reinterpret_cast<std::array<double,4>*>(aux), scm2cpp::span<double>(work, work_len), scm2cpp::span<double>(out, out_len), m, maxiter, pgtol, ftol, maxls, ib, lbv, nv, n, p, k);
  { scm2cpp::span<double> s(w, w_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(x, x_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(y, y_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(aux, 4); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(work, work_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(out, out_len); scm2cpp::cu::need_host(s); }
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" double scm2cpp_lbfgs_fg(std::int64_t kind, double* w, std::int64_t w_len, double* g, std::int64_t g_len, double* x, std::int64_t x_len, double* y, std::int64_t y_len, double* aux, double* work, std::int64_t work_len, std::int64_t n, std::int64_t p, std::int64_t k) {
  double scm2cpp_r = lbfgs_fg(kind, scm2cpp::span<double>(w, w_len), scm2cpp::span<double>(g, g_len), scm2cpp::span<double>(x, x_len), scm2cpp::span<double>(y, y_len), *reinterpret_cast<std::array<double,4>*>(aux), scm2cpp::span<double>(work, work_len), n, p, k);
  { scm2cpp::span<double> s(w, w_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(g, g_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(x, x_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(y, y_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(aux, 4); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(work, work_len); scm2cpp::cu::need_host(s); }
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
