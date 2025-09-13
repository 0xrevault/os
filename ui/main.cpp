#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QDebug>
#include <QFontDatabase>
#include <QFont>

int main(int argc, char *argv[])
{
    qputenv("QSG_INFO", "1");
    qputenv("QT_LOGGING_RULES", "qt.qml.engine=true;qt.qml.binding=true;qt.scenegraph.general=true");

    QGuiApplication app(argc, argv);

    int id = QFontDatabase::addApplicationFont(":/qt/qml/revo_wallet/assets/fonts/NotoSansSC-Regular.ttf");
    if (id < 0) qWarning() << "Failed to load Chinese font";
    else {
        const auto fam = QFontDatabase::applicationFontFamilies(id).value(0);
        if (!fam.isEmpty()) app.setFont(QFont(fam));
     }

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule("revo_wallet", "Main");

    return app.exec();
}
