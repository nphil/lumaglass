// Probe: load a 64-bit Mali blob, draw a triangle offscreen, read it back, time a full-HD fill.
#include <dlfcn.h>
#include <stdio.h>
#include <stdint.h>
#include <time.h>

typedef void *EGLDisplay, *EGLConfig, *EGLSurface, *EGLContext;
typedef int EGLint;
typedef unsigned int GLuint, GLenum;
typedef int GLint, GLsizei;
typedef float GLfloat;
typedef unsigned char GLubyte;

#define L(name, ret, ...) static ret (*name)(__VA_ARGS__);
L(eglGetDisplay, EGLDisplay, void *)
L(eglInitialize, unsigned, EGLDisplay, EGLint *, EGLint *)
L(eglQueryString, const char *, EGLDisplay, EGLint)
L(eglChooseConfig, unsigned, EGLDisplay, const EGLint *, EGLConfig *, EGLint, EGLint *)
L(eglCreatePbufferSurface, EGLSurface, EGLDisplay, EGLConfig, const EGLint *)
L(eglCreateContext, EGLContext, EGLDisplay, EGLConfig, EGLContext, const EGLint *)
L(eglMakeCurrent, unsigned, EGLDisplay, EGLSurface, EGLSurface, EGLContext)
L(eglGetError, EGLint, void)
L(eglBindAPI, unsigned, unsigned)
L(eglTerminate, unsigned, EGLDisplay)
L(glGetString, const GLubyte *, GLenum)
L(glCreateShader, GLuint, GLenum)
L(glShaderSource, void, GLuint, GLsizei, const char *const *, const GLint *)
L(glCompileShader, void, GLuint)
L(glGetShaderiv, void, GLuint, GLenum, GLint *)
L(glCreateProgram, GLuint, void)
L(glAttachShader, void, GLuint, GLuint)
L(glLinkProgram, void, GLuint)
L(glUseProgram, void, GLuint)
L(glVertexAttribPointer, void, GLuint, GLint, GLenum, unsigned char, GLsizei, const void *)
L(glEnableVertexAttribArray, void, GLuint)
L(glDrawArrays, void, GLenum, GLint, GLsizei)
L(glViewport, void, GLint, GLint, GLsizei, GLsizei)
L(glClearColor, void, GLfloat, GLfloat, GLfloat, GLfloat)
L(glClear, void, GLenum)
L(glReadPixels, void, GLint, GLint, GLsizei, GLsizei, GLenum, GLenum, void *)
L(glFinish, void, void)
L(glGetUniformLocation, GLint, GLuint, const char *)
L(glUniform1f, void, GLint, GLfloat)

static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec + t.tv_nsec / 1e9; }

static GLuint shader(GLenum type, const char *src) {
  GLuint s = glCreateShader(type); glShaderSource(s, 1, &src, 0); glCompileShader(s);
  GLint ok = 0; glGetShaderiv(s, 0x8B81, &ok); if (!ok) printf("shader compile failed\n"); return s;
}

int main(int argc, char **argv) {
  const char *lib = argc > 1 ? argv[1] : "libmali.so";
  void *h = dlopen(lib, RTLD_NOW | RTLD_GLOBAL);
  if (!h) { printf("dlopen: %s\n", dlerror()); return 1; }
#define S(name) *(void **)&name = dlsym(h, #name); if (!name) { printf("missing %s\n", #name); return 1; }
  S(eglGetDisplay) S(eglInitialize) S(eglQueryString) S(eglChooseConfig) S(eglCreatePbufferSurface) S(eglCreateContext)
  S(eglMakeCurrent) S(eglGetError) S(eglBindAPI) S(eglTerminate) S(glGetString) S(glCreateShader) S(glShaderSource)
  S(glCompileShader) S(glGetShaderiv) S(glCreateProgram) S(glAttachShader) S(glLinkProgram) S(glUseProgram)
  S(glVertexAttribPointer) S(glEnableVertexAttribArray) S(glDrawArrays) S(glViewport) S(glClearColor) S(glClear)
  S(glReadPixels) S(glFinish) S(glGetUniformLocation) S(glUniform1f)

  EGLDisplay d = eglGetDisplay(0);
  EGLint maj = 0, min = 0;
  if (!d || !eglInitialize(d, &maj, &min)) { printf("eglInitialize failed: 0x%x\n", eglGetError()); return 2; }
  printf("EGL %d.%d vendor=%s version=%s\n", maj, min, eglQueryString(d, 0x3053), eglQueryString(d, 0x3054));
  const int W = 1920, H = 1080;
  EGLint ca[] = {0x3033, 0x0001 /*PBUFFER_BIT*/, 0x3040, 0x0004 /*ES2*/, 0x3024, 8, 0x3023, 8, 0x3022, 8, 0x3021, 8, 0x3038};
  EGLConfig cfg; EGLint n = 0;
  if (!eglChooseConfig(d, ca, &cfg, 1, &n) || n < 1) { printf("no config: 0x%x\n", eglGetError()); return 3; }
  EGLint sa[] = {0x3057, W, 0x3056, H, 0x3038};
  EGLSurface s = eglCreatePbufferSurface(d, cfg, sa);
  eglBindAPI(0x30A0);
  EGLint xa[] = {0x3098, 2, 0x3038};
  EGLContext c = eglCreateContext(d, cfg, 0, xa);
  if (!s || !c || !eglMakeCurrent(d, s, s, c)) { printf("surface/context failed: 0x%x\n", eglGetError()); return 4; }
  printf("GL_RENDERER=%s\nGL_VERSION=%s\n", glGetString(0x1F01), glGetString(0x1F02));

  GLuint p = glCreateProgram();
  glAttachShader(p, shader(0x8B31, "attribute vec2 a; void main(){gl_Position=vec4(a,0.0,1.0);}"));
  glAttachShader(p, shader(0x8B30,
    "precision mediump float; uniform float t;"
    "void main(){ vec2 q=gl_FragCoord.xy/vec2(1920.0,1080.0); float v=0.0;"
    " for(int i=0;i<16;i++){ v+=sin(q.x*float(i)+t)*cos(q.y*float(i)-t); }"
    " gl_FragColor=vec4(1.0,0.0,0.0,1.0)*(1.0-step(100.0,abs(v)))+vec4(0.0,0.0,0.0,v*0.0); }"));
  glLinkProgram(p); glUseProgram(p);
  GLint ut = glGetUniformLocation(p, "t");
  float tri[] = {-1, -1, 3, -1, -1, 3};
  glVertexAttribPointer(0, 2, 0x1406, 0, 0, tri); glEnableVertexAttribArray(0);
  glViewport(0, 0, W, H); glClearColor(0, 0, 1, 1); glClear(0x4000);
  glDrawArrays(0x0004, 0, 3); glFinish();
  uint8_t px[4] = {0};
  glReadPixels(W / 2, H / 2, 1, 1, 0x1908, 0x1401, px);
  printf("centre pixel rgba=%u,%u,%u,%u (expect 255,0,0,255)\n", px[0], px[1], px[2], px[3]);

  int frames = 120; double t0 = now();
  for (int i = 0; i < frames; i++) { glUniform1f(ut, i * 0.01f); glDrawArrays(0x0004, 0, 3); glFinish(); }
  double dt = now() - t0;
  printf("full-HD 16-term shader: %.2f ms per frame over %d frames\n", dt * 1000 / frames, frames);

  // Driver CPU cost: many tiny draws, as a UI frame issues.
  glViewport(0, 0, 16, 16);
  for (int run = 0; run < 3; run++) {
    t0 = now();
    for (int f = 0; f < 60; f++) {
      for (int i = 0; i < 2000; i++) { glUniform1f(ut, i * 0.001f); glDrawArrays(0x0004, 0, 3); }
      glFinish();
    }
    dt = now() - t0;
    printf("2000 tiny draws: %.2f ms per frame over 60 frames\n", dt * 1000 / 60);
  }
  eglMakeCurrent(d, 0, 0, 0); eglTerminate(d);
  return 0;
}
