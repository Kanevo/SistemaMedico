import Foundation

// MARK: - Extensiones de Notification.Name
extension Notification.Name {
    static let productosActualizados = Notification.Name("productosActualizados")
    static let pedidosActualizados = Notification.Name("pedidosActualizados")
    static let stockBajo = Notification.Name("stockBajo")
    static let pedidoEnviado = Notification.Name("pedidoEnviado")
    static let pedidoCambiado = Notification.Name("pedidoCambiado")
}
