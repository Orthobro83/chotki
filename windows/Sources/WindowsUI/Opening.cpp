#define NOMINMAX
#define UNICODE
#define _UNICODE
#include "WindowsUI.h"
#include <windows.h>
#include <gdiplus.h>
#include <algorithm>
#include <cstring>

// Geometry comes from ChotkiCore. Timing matches macOS OpeningTiming.
static double knots[96], bars[48], foot[8];
static int knotCount, barCount;
static HWND curtain;
static ULONGLONG started;
static double fixedMilliseconds=-1;
static ULONG_PTR graphicsToken;
static bool pending=true;
// Bounded lifecycle-review observation: 0 pending, 1 skipped, 2 active,
// 3 finished, 100+graphics status or 1000+Win32 creation error.
static int observedState;
extern "C" int ch_opening_state(void) { return observedState; }
static double clamp(double value) { return std::max(0.0,std::min(1.0,value)); }
extern "C" void ch_opening_geometry(const double *k,int32_t count,const double *b,int32_t rectangles,const double *f) {
    knotCount=std::min(32,(int)count); barCount=std::min(12,(int)rectangles);
    std::memcpy(knots,k,knotCount*3*sizeof(double)); std::memcpy(bars,b,barCount*4*sizeof(double)); std::memcpy(foot,f,sizeof(foot));
}
extern "C" void ch_draw_backdrop(void *dc,int width,int height,int offsetX,int offsetY);
static void drawOpening(HWND hwnd,HDC dc) {
    RECT r; GetClientRect(hwnd,&r);
        { Gdiplus::Graphics g(dc); g.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
        ch_draw_backdrop(dc,r.right,r.bottom,0,0);
        double ms=fixedMilliseconds>=0 ? fixedMilliseconds : (double)(GetTickCount64()-started);
        double opacity=ms<3300 ? 1 : clamp(1-(ms-3300)/400);
        double side=220.0*GetDpiForWindow(hwnd)/96*(.85+.15*clamp(ms/1800));
        double left=(r.right-side)/2,top=(r.bottom-side)/2;
        for(int i=0;i<knotCount;i++) {
            double alpha=clamp((ms-i*1600.0/(knotCount-1))/160)*opacity;
            Gdiplus::SolidBrush gold(Gdiplus::Color((BYTE)(alpha*255),201,162,39));
            double *k=knots+i*3;
            g.FillEllipse(&gold,(Gdiplus::REAL)(left+(k[0]-k[2])*side),(Gdiplus::REAL)(top+(k[1]-k[2])*side),(Gdiplus::REAL)(k[2]*side*2),(Gdiplus::REAL)(k[2]*side*2));
        }
        Gdiplus::SolidBrush cross(Gdiplus::Color((BYTE)(clamp((ms-1640)/160)*opacity*255),201,162,39));
        for(int i=0;i<barCount;i++) { double *b=bars+i*4;
            g.FillRectangle(&cross,(Gdiplus::REAL)(left+b[0]*side),(Gdiplus::REAL)(top+b[1]*side),(Gdiplus::REAL)(b[2]*side),(Gdiplus::REAL)(b[3]*side)); }
        Gdiplus::PointF polygon[4]; for(int i=0;i<4;i++) polygon[i]=Gdiplus::PointF((Gdiplus::REAL)(left+foot[i*2]*side),(Gdiplus::REAL)(top+foot[i*2+1]*side));
        g.FillPolygon(&cross,polygon,4);
        }
}
static LRESULT CALLBACK openingProcedure(HWND hwnd,UINT message,WPARAM wp,LPARAM lp) {
    switch(message) {
    case WM_ERASEBKGND: return 1;
    case WM_TIMER:
        if(GetTickCount64()-started>=3700) { DestroyWindow(hwnd); ch_post(-10,0); }
        else InvalidateRect(hwnd,NULL,FALSE);
        return 0;
    case WM_PAINT: { PAINTSTRUCT paint; HDC dc=BeginPaint(hwnd,&paint); drawOpening(hwnd,dc); EndPaint(hwnd,&paint); return 0; }
    case WM_PRINTCLIENT: drawOpening(hwnd,(HDC)wp); return 0;
    case WM_NCDESTROY: KillTimer(hwnd,1); observedState=3; curtain=NULL; return DefWindowProcW(hwnd,message,wp,lp);
    }
    return DefWindowProcW(hwnd,message,wp,lp);
}
static bool createCurtain(HWND parent,double milliseconds) {
    if(curtain || knotCount<2) return false;
    if(!graphicsToken) { Gdiplus::GdiplusStartupInput input; Gdiplus::Status status=Gdiplus::GdiplusStartup(&graphicsToken,&input,NULL); if(status!=Gdiplus::Ok) { observedState=100+status; return false; } }
    WNDCLASSW cls={}; cls.lpfnWndProc=openingProcedure; cls.hInstance=GetModuleHandleW(NULL); cls.hCursor=LoadCursorW(NULL,IDC_ARROW); cls.lpszClassName=L"ChotkiOpening"; RegisterClassW(&cls);
    RECT r; GetClientRect(parent,&r); fixedMilliseconds=milliseconds; started=GetTickCount64();
    curtain=CreateWindowExW(0,cls.lpszClassName,L"The opening",WS_CHILD|WS_VISIBLE,0,0,r.right,r.bottom,parent,NULL,cls.hInstance,NULL);
    if(!curtain) { observedState=1000+GetLastError(); return false; }
    observedState=2;
    SetWindowPos(curtain,HWND_TOP,0,0,0,0,SWP_NOMOVE|SWP_NOSIZE|SWP_NOACTIVATE);
    if(milliseconds<0) SetTimer(curtain,1,33,NULL);
    return true;
}
extern "C" int ch_opening_active(void) { return curtain!=NULL; }
extern "C" void ch_opening_resize(void *parent) { if(curtain) { RECT r; GetClientRect((HWND)parent,&r); MoveWindow(curtain,0,0,r.right,r.bottom,TRUE); } }
extern "C" void ch_opening_start(void *parent,int skip) {
    if(!pending || !IsWindowVisible((HWND)parent)) return;
    pending=false; observedState=1;
    BOOL animate=TRUE; SystemParametersInfoW(SPI_GETCLIENTAREAANIMATION,0,&animate,0);
    if(!skip && animate) createCurtain((HWND)parent,-1);
}
extern "C" int ch_opening_fixture(void *parent,double milliseconds) {
    if(curtain) DestroyWindow(curtain);
    if(milliseconds<0) return 1;
    return createCurtain((HWND)parent,milliseconds);
}
extern "C" void ch_opening_shutdown(void) { if(curtain) DestroyWindow(curtain); if(graphicsToken) { Gdiplus::GdiplusShutdown(graphicsToken); graphicsToken=0; } }

extern "C" void ch_opening_paint(void *dc) { if(curtain) drawOpening(curtain,(HDC)dc); }
