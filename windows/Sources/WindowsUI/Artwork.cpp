#define NOMINMAX
#include <windows.h>
#include <gdiplus.h>
#include <memory>
#include <string>
#include <algorithm>
#include <cmath>
#include <vector>

extern "C" void ch_draw_art(void *context, const wchar_t *path, int x, int y, int width, int height, double fx, double fy) {
    if (!path || width<=0 || height<=0) return;
    static ULONG_PTR token = 0;
    if (!token) { Gdiplus::GdiplusStartupInput input; if (Gdiplus::GdiplusStartup(&token, &input, nullptr) != Gdiplus::Ok) return; }
    static std::wstring held;
    static std::unique_ptr<Gdiplus::Image> image;
    if (held != path) { held = path; image.reset(Gdiplus::Image::FromFile(path)); }
    if (!image || image->GetLastStatus() != Gdiplus::Ok) return;
    double iw = image->GetWidth(), ih = image->GetHeight();
    // Same cover + 8% overscan and approved subject crop as the Mac resting frame.
    double scale = std::max(width / iw, height / ih) * 1.08;
    double rw = iw * scale, rh = ih * scale;
    double ox = std::clamp(width * .5 - rw * fx, width - rw, 0.0);
    double oy = std::clamp(height * .4 - rh * fy, height - rh, 0.0);
    Gdiplus::Graphics graphics(static_cast<HDC>(context));
    graphics.SetInterpolationMode(Gdiplus::InterpolationModeHighQualityBicubic);
    graphics.DrawImage(image.get(), Gdiplus::RectF(float(x + ox), float(y + oy), float(rw), float(rh)));
    Gdiplus::LinearGradientBrush shade(Gdiplus::Point(x,y), Gdiplus::Point(x,y + height),
                                     Gdiplus::Color(0,0,0,0), Gdiplus::Color(220,0,0,0));
    Gdiplus::Color stops[] = {Gdiplus::Color(0,0,0,0),Gdiplus::Color(0,0,0,0),Gdiplus::Color(217,0,0,0)};
    Gdiplus::REAL positions[] = {0.0f,0.2f,1.0f};
    shade.SetInterpolationColors(stops,positions,3);
    graphics.FillRectangle(&shade,x,y,width,height);
}

// Sample the same two restrained radial washes used by the macOS backdrop.
extern "C" void ch_draw_backdrop(void *context,int width,int height,int offsetX,int offsetY) {
    if(width<=0 || height<=0) return;
    constexpr int sw=240,sh=180;
    static int heldW=0,heldH=0;
    static std::vector<unsigned int> pixels(sw*sh);
    if(heldW!=width || heldH!=height) {
        heldW=width; heldH=height;
        for(int y=0;y<sh;y++) for(int x=0;x<sw;x++) {
            double gx=x*double(width)/(sw-1),gy=y*double(height)/(sh-1);
            double a=.14*std::max(0.0,1-std::hypot(gx,gy)/(width*.7));
            double b=.10*std::max(0.0,1-std::hypot(width-gx,height-gy)/(width*.6));
            int r=int((21*(1-a)+232*a)*(1-b)+201*b);
            int g=int((22*(1-a)+223*a)*(1-b)+162*b);
            int blue=int((28*(1-a)+205*a)*(1-b)+39*b);
            pixels[y*sw+x]=(r<<16)|(g<<8)|blue;
        }
    }
    BITMAPINFO info={}; info.bmiHeader.biSize=sizeof(BITMAPINFOHEADER); info.bmiHeader.biWidth=sw;
    info.bmiHeader.biHeight=-sh; info.bmiHeader.biPlanes=1; info.bmiHeader.biBitCount=32;
    StretchDIBits(static_cast<HDC>(context),-offsetX,-offsetY,width,height,0,0,sw,sh,pixels.data(),&info,DIB_RGB_COLORS,SRCCOPY);
}
