import Foundation
import CoreData

// Modelo para representar un Pedido
struct PedidoModel {
    let cliente: String
    let destino: String
    let total: Double
    let fechaCreacion: Date
    let estado: EstadoPedido
    
    // Inicializador desde NSManagedObject
    init(from managedObject: NSManagedObject) {
        self.cliente = managedObject.value(forKey: "cliente") as? String ?? ""
        self.destino = managedObject.value(forKey: "destino") as? String ?? ""
        self.total = managedObject.value(forKey: "total") as? Double ?? 0.0
        self.fechaCreacion = managedObject.value(forKey: "fechaCreacion") as? Date ?? Date()
        
        let estadoString = managedObject.value(forKey: "estado") as? String ?? "Pendiente"
        self.estado = EstadoPedido(rawValue: estadoString) ?? .pendiente
    }
    
    // Formatear fecha para mostrar
    var fechaFormateada: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: fechaCreacion)
    }
    
    // Total formateado como moneda
    var totalFormateado: String {
        return "S/. \(String(format: "%.2f", total))"
    }
}

// Enum para estados del pedido
enum EstadoPedido: String, CaseIterable {
    case pendiente = "Pendiente"
    case preparando = "Preparando"
    case enviado = "Enviado"
    case entregado = "Entregado"
    case cancelado = "Cancelado"
    
    // Color asociado al estado
    var colorRepresentativo: String {
        switch self {
        case .pendiente:
            return "systemOrange"
        case .preparando:
            return "systemBlue"
        case .enviado:
            return "systemPurple"
        case .entregado:
            return "systemGreen"
        case .cancelado:
            return "systemRed"
        }
    }
    
    // Descripción del estado
    var descripcion: String {
        switch self {
        case .pendiente:
            return "Esperando procesamiento"
        case .preparando:
            return "Preparando pedido"
        case .enviado:
            return "En camino al destino"
        case .entregado:
            return "Pedido completado"
        case .cancelado:
            return "Pedido cancelado"
        }
    }
}

// Extensión para destinos predefinidos en Perú
extension PedidoModel {
    static let destinosPeru = [
        "Lima",
        "Arequipa",
        "Trujillo",
        "Chiclayo",
        "Piura",
        "Iquitos",
        "Cusco",
        "Huancayo",
        "Chimbote",
        "Tacna",
        "Ica",
        "Sullana",
        "Chincha",
        "Huánuco",
        "Pucallpa"
    ]
}
