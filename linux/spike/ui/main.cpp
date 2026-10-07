#include "Bridge.h"

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

int main(int argc, char *argv[]) {
    QGuiApplication application(argc, argv);
    if (application.arguments().size() != 2) return 2;
    Bridge bridge(application.arguments().at(1));
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("bridge", &bridge);
    engine.loadFromModule("ChotkiSpike", "Main");
    if (engine.rootObjects().isEmpty()) return 3;
    return application.exec();
}
