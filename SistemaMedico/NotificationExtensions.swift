import Foundation

// MARK: - ✅ EXTENSIONES DE NOTIFICATION.NAME ACTUALIZADAS

extension Notification.Name {
    // ✅ NOTIFICACIONES EXISTENTES - MANTENIDAS
    static let productosActualizados = Notification.Name("productosActualizados")
    static let pedidosActualizados = Notification.Name("pedidosActualizados")
    static let stockBajo = Notification.Name("stockBajo")
    static let pedidoEnviado = Notification.Name("pedidoEnviado")
    static let pedidoCambiado = Notification.Name("pedidoCambiado")
    
    // ✅ NUEVAS NOTIFICACIONES PARA SINCRONIZACIÓN FIREBASE
    /// Se envía cuando un pedido se envía exitosamente a Firebase automáticamente
    static let pedidoEnviadoAFirebase = Notification.Name("pedidoEnviadoAFirebase")
    
    /// Se envía cuando se completa una sincronización manual con Firebase
    static let sincronizacionCompletada = Notification.Name("sincronizacionCompletada")
    
    /// Se envía cuando hay un error de sincronización con Firebase
    static let errorSincronizacion = Notification.Name("errorSincronizacion")
    
    /// Se envía cuando se actualiza el estado de un pedido en Firebase
    static let pedidoActualizadoEnFirebase = Notification.Name("pedidoActualizadoEnFirebase")
}
