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
extern "C" int scm2cpp_sym_eigen(double* a, int a_len, double* v, int v_len, double* ev, int ev_len, double* e, int e_len, int m) {
  int scm2cpp_r = sym_eigen(scm2cpp::span<double>(a, a_len), scm2cpp::span<double>(v, v_len), scm2cpp::span<double>(ev, ev_len), scm2cpp::span<double>(e, e_len), m);
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
extern "C" int scm2cpp_eig_order(double* ev, int ev_len, int* ord, int ord_len, int m) {
  int scm2cpp_r = eig_order(scm2cpp::span<double>(ev, ev_len), scm2cpp::span<int>(ord, ord_len), m);
  { scm2cpp::span<double> s(ev, ev_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<int> s(ord, ord_len); scm2cpp::cu::need_host(s); }
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" int scm2cpp_sym_eigen_top(double* a, int a_len, double* v, int v_len, double* ev, int ev_len, double* e, int e_len, int m, int k) {
  int scm2cpp_r = sym_eigen_top(scm2cpp::span<double>(a, a_len), scm2cpp::span<double>(v, v_len), scm2cpp::span<double>(ev, ev_len), scm2cpp::span<double>(e, e_len), m, k);
  { scm2cpp::span<double> s(a, a_len); scm2cpp::cu::need_host(s); }
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
extern "C" int scm2cpp_ica_sym(double* w, int w_len, double* a, int a_len, double* v, int v_len, double* ev, int ev_len, double* e, int e_len, double* t, int t_len, int m) {
  int scm2cpp_r = ica_sym(scm2cpp::span<double>(w, w_len), scm2cpp::span<double>(a, a_len), scm2cpp::span<double>(v, v_len), scm2cpp::span<double>(ev, ev_len), scm2cpp::span<double>(e, e_len), scm2cpp::span<double>(t, t_len), m);
  { scm2cpp::span<double> s(w, w_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(a, a_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(v, v_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(ev, ev_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(e, e_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(t, t_len); scm2cpp::cu::need_host(s); }
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" int scm2cpp_fastica(double* x, int x_len, double* winit, int winit_len, double* comps, int comps_len, double* white, int white_len, double* unmix, int unmix_len, double* mean, int mean_len, int maxiter, double tol, int n, int p, int nc) {
  int scm2cpp_r = fastica(scm2cpp::span<double>(x, x_len), scm2cpp::span<double>(winit, winit_len), scm2cpp::span<double>(comps, comps_len), scm2cpp::span<double>(white, white_len), scm2cpp::span<double>(unmix, unmix_len), scm2cpp::span<double>(mean, mean_len), maxiter, tol, n, p, nc);
  { scm2cpp::span<double> s(x, x_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(winit, winit_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(comps, comps_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(white, white_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(unmix, unmix_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(mean, mean_len); scm2cpp::cu::need_host(s); }
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" int scm2cpp_gmm_mstep(double* x, int x_len, double* resp, int resp_len, double* weights, int weights_len, double* means, int means_len, double* prec, int prec_len, double* dw, int dw_len, double* cov, int cov_len, double* l, int l_len, double* u, int u_len, double reg, int norm, int n, int p, int kc) {
  int scm2cpp_r = gmm_mstep(scm2cpp::span<double>(x, x_len), scm2cpp::span<double>(resp, resp_len), scm2cpp::span<double>(weights, weights_len), scm2cpp::span<double>(means, means_len), scm2cpp::span<double>(prec, prec_len), scm2cpp::span<double>(dw, dw_len), scm2cpp::span<double>(cov, cov_len), scm2cpp::span<double>(l, l_len), scm2cpp::span<double>(u, u_len), reg, norm, n, p, kc);
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
extern "C" double scm2cpp_gmm_estep(double* x, int x_len, double* resp, int resp_len, double* weights, int weights_len, double* means, int means_len, double* prec, int prec_len, double* wlp, int wlp_len, double* y, int y_len, double* u, int u_len, double* mu, int mu_len, int n, int p, int kc) {
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
extern "C" int scm2cpp_gmm(double* x, int x_len, double* resp, int resp_len, double* weights, int weights_len, double* means, int means_len, double* prec, int prec_len, double* labels, int labels_len, double* out, int out_len, int maxiter, double tol, double reg, int n, int p, int kc) {
  int scm2cpp_r = gmm(scm2cpp::span<double>(x, x_len), scm2cpp::span<double>(resp, resp_len), scm2cpp::span<double>(weights, weights_len), scm2cpp::span<double>(means, means_len), scm2cpp::span<double>(prec, prec_len), scm2cpp::span<double>(labels, labels_len), scm2cpp::span<double>(out, out_len), maxiter, tol, reg, n, p, kc);
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
extern "C" double scm2cpp_logistic_fg(double* coef, int coef_len, double* g, int g_len, double* x, int x_len, double* y, int y_len, double* z, int z_len, double l2, int multi, int fitint, int n, int p, int k) {
  double scm2cpp_r = logistic_fg(scm2cpp::span<double>(coef, coef_len), scm2cpp::span<double>(g, g_len), scm2cpp::span<double>(x, x_len), scm2cpp::span<double>(y, y_len), scm2cpp::span<double>(z, z_len), l2, multi, fitint, n, p, k);
  { scm2cpp::span<double> s(coef, coef_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(g, g_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(x, x_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(y, y_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(z, z_len); scm2cpp::cu::need_host(s); }
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" int scm2cpp_logistic_lbfgs(double* x, int x_len, double* y, int y_len, double* coef, int coef_len, double* out, int out_len, double c, int maxiter, double tol, int multi, int fitint, int n, int p, int k) {
  int scm2cpp_r = logistic_lbfgs(scm2cpp::span<double>(x, x_len), scm2cpp::span<double>(y, y_len), scm2cpp::span<double>(coef, coef_len), scm2cpp::span<double>(out, out_len), c, maxiter, tol, multi, fitint, n, p, k);
  { scm2cpp::span<double> s(x, x_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(y, y_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(coef, coef_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(out, out_len); scm2cpp::cu::need_host(s); }
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" double scm2cpp_huber_fg(double* coef, int coef_len, double* g, int g_len, double* x, int x_len, double* y, int y_len, double* z, int z_len, double epsilon, double alpha, int fitint, int n, int p) {
  double scm2cpp_r = huber_fg(scm2cpp::span<double>(coef, coef_len), scm2cpp::span<double>(g, g_len), scm2cpp::span<double>(x, x_len), scm2cpp::span<double>(y, y_len), scm2cpp::span<double>(z, z_len), epsilon, alpha, fitint, n, p);
  { scm2cpp::span<double> s(coef, coef_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(g, g_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(x, x_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(y, y_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(z, z_len); scm2cpp::cu::need_host(s); }
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" int scm2cpp_huber(double* x, int x_len, double* y, int y_len, double* coef, int coef_len, double* out, int out_len, double epsilon, double alpha, int maxiter, double tol, int fitint, int n, int p) {
  int scm2cpp_r = huber(scm2cpp::span<double>(x, x_len), scm2cpp::span<double>(y, y_len), scm2cpp::span<double>(coef, coef_len), scm2cpp::span<double>(out, out_len), epsilon, alpha, maxiter, tol, fitint, n, p);
  { scm2cpp::span<double> s(x, x_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(y, y_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(coef, coef_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(out, out_len); scm2cpp::cu::need_host(s); }
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" double scm2cpp_glm_fg(double* coef, int coef_len, double* g, int g_len, double* x, int x_len, double* y, int y_len, double* z, int z_len, int family, double power, double l2, int fitint, int n, int p) {
  double scm2cpp_r = glm_fg(scm2cpp::span<double>(coef, coef_len), scm2cpp::span<double>(g, g_len), scm2cpp::span<double>(x, x_len), scm2cpp::span<double>(y, y_len), scm2cpp::span<double>(z, z_len), family, power, l2, fitint, n, p);
  { scm2cpp::span<double> s(coef, coef_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(g, g_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(x, x_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(y, y_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(z, z_len); scm2cpp::cu::need_host(s); }
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" int scm2cpp_glm(double* x, int x_len, double* y, int y_len, double* coef, int coef_len, double* out, int out_len, int family, double power, double alpha, int maxiter, double tol, int fitint, int n, int p) {
  int scm2cpp_r = glm(scm2cpp::span<double>(x, x_len), scm2cpp::span<double>(y, y_len), scm2cpp::span<double>(coef, coef_len), scm2cpp::span<double>(out, out_len), family, power, alpha, maxiter, tol, fitint, n, p);
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
extern "C" int scm2cpp_lb_dcstep(double* cs, double fp, double dp, double stpmin, double stpmax) {
  int scm2cpp_r = lb_dcstep(*reinterpret_cast<std::array<double,8>*>(cs), fp, dp, stpmin, stpmax);
  { scm2cpp::span<double> s(cs, 8); scm2cpp::cu::need_host(s); }
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" int scm2cpp_lb_search_start(double* ls, double f, double g, double stp, double stpmin, double stpmax, double ftol) {
  int scm2cpp_r = lb_search_start(*reinterpret_cast<std::array<double,16>*>(ls), f, g, stp, stpmin, stpmax, ftol);
  { scm2cpp::span<double> s(ls, 16); scm2cpp::cu::need_host(s); }
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" int scm2cpp_lb_search_step(double* ls, double* cs, double f, double g, double ftol, double gtol, double xtol, double stpmin, double stpmax) {
  int scm2cpp_r = lb_search_step(*reinterpret_cast<std::array<double,16>*>(ls), *reinterpret_cast<std::array<double,8>*>(cs), f, g, ftol, gtol, xtol, stpmin, stpmax);
  { scm2cpp::span<double> s(ls, 16); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(cs, 8); scm2cpp::cu::need_host(s); }
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" double scm2cpp_lb_dot(double* a, int a_len, double* b, int b_len, int nv) {
  double scm2cpp_r = lb_dot(scm2cpp::span<double>(a, a_len), scm2cpp::span<double>(b, b_len), nv);
  { scm2cpp::span<double> s(a, a_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(b, b_len); scm2cpp::cu::need_host(s); }
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" double scm2cpp_lb_dot_row(double* mem, int mem_len, int slot, double* v, int v_len, int nv) {
  double scm2cpp_r = lb_dot_row(scm2cpp::span<double>(mem, mem_len), slot, scm2cpp::span<double>(v, v_len), nv);
  { scm2cpp::span<double> s(mem, mem_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(v, v_len); scm2cpp::cu::need_host(s); }
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" double scm2cpp_lb_dot_rows(double* a, int a_len, int ra, double* b, int b_len, int rb, int nv) {
  double scm2cpp_r = lb_dot_rows(scm2cpp::span<double>(a, a_len), ra, scm2cpp::span<double>(b, b_len), rb, nv);
  { scm2cpp::span<double> s(a, a_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(b, b_len); scm2cpp::cu::need_host(s); }
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" double scm2cpp_lb_projgr(double* g, int g_len, double* w, int w_len, int ib, double lbv, int nv) {
  double scm2cpp_r = lb_projgr(scm2cpp::span<double>(g, g_len), scm2cpp::span<double>(w, w_len), ib, lbv, nv);
  { scm2cpp::span<double> s(g, g_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(w, w_len); scm2cpp::cu::need_host(s); }
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" int scm2cpp_lb_hv(double* q, int q_len, double* smem, int smem_len, double* ymem, int ymem_len, double* rho, int rho_len, double* al, int al_len, double theta, int col, int head, int m, int nv) {
  int scm2cpp_r = lb_hv(scm2cpp::span<double>(q, q_len), scm2cpp::span<double>(smem, smem_len), scm2cpp::span<double>(ymem, ymem_len), scm2cpp::span<double>(rho, rho_len), scm2cpp::span<double>(al, al_len), theta, col, head, m, nv);
  { scm2cpp::span<double> s(q, q_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(smem, smem_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(ymem, ymem_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(rho, rho_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(al, al_len); scm2cpp::cu::need_host(s); }
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" double scm2cpp_lb_vbv(double* v, int v_len, double* smem, int smem_len, double* ymem, int ymem_len, double* rho, int rho_len, double* bm, int bm_len, double* sb, int sb_len, double theta, int col, int head, int m, int nv) {
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
extern "C" int scm2cpp_lb_direction(double* w, int w_len, double* g, int g_len, double* d, int d_len, double* q, int q_len, double* e, int e_len, double* smem, int smem_len, double* ymem, int ymem_len, double* rho, int rho_len, double* al, int al_len, double* bm, int bm_len, double* sb, int sb_len, double theta, int col, int head, int m, int ib, double lbv, int nv) {
  int scm2cpp_r = lb_direction(scm2cpp::span<double>(w, w_len), scm2cpp::span<double>(g, g_len), scm2cpp::span<double>(d, d_len), scm2cpp::span<double>(q, q_len), scm2cpp::span<double>(e, e_len), scm2cpp::span<double>(smem, smem_len), scm2cpp::span<double>(ymem, ymem_len), scm2cpp::span<double>(rho, rho_len), scm2cpp::span<double>(al, al_len), scm2cpp::span<double>(bm, bm_len), scm2cpp::span<double>(sb, sb_len), theta, col, head, m, ib, lbv, nv);
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
extern "C" int scm2cpp_lbfgs(int kind, double* w, int w_len, double* x, int x_len, double* y, int y_len, double* aux, double* work, int work_len, double* out, int out_len, int m, int maxiter, double pgtol, double ftol, int maxls, int ib, double lbv, int nv, int n, int p, int k) {
  int scm2cpp_r = lbfgs(kind, scm2cpp::span<double>(w, w_len), scm2cpp::span<double>(x, x_len), scm2cpp::span<double>(y, y_len), *reinterpret_cast<std::array<double,4>*>(aux), scm2cpp::span<double>(work, work_len), scm2cpp::span<double>(out, out_len), m, maxiter, pgtol, ftol, maxls, ib, lbv, nv, n, p, k);
  { scm2cpp::span<double> s(w, w_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(x, x_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(y, y_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(aux, 4); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(work, work_len); scm2cpp::cu::need_host(s); }
  { scm2cpp::span<double> s(out, out_len); scm2cpp::cu::need_host(s); }
  scm2cpp::cu::end_call();
  return scm2cpp_r;
}
extern "C" double scm2cpp_lbfgs_fg(int kind, double* w, int w_len, double* g, int g_len, double* x, int x_len, double* y, int y_len, double* aux, double* work, int work_len, int n, int p, int k) {
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
