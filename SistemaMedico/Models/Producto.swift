import Foundation
import CoreData

// Modelo para representar un Producto médico
struct ProductoModel {
    let nombre: String
    let categoria: String
    let precio: Double
    let stock: Int32
    let stockMinimo: Int32
    let fechaCreacion: Date
    let activo: Bool
    
    // Inicializador desde NSManagedObject
    init(from managedObject: NSManagedObject) {
        self.nombre = managedObject.value(forKey: "nombre") as? String ?? ""
        self.categoria = managedObject.value(forKey: "categoria") as? String ?? ""
        self.precio = managedObject.value(forKey: "precio") as? Double ?? 0.0
        self.stock = managedObject.value(forKey: "stock") as? Int32 ?? 0
        self.stockMinimo = managedObject.value(forKey: "stockMinimo") as? Int32 ?? 0
        self.fechaCreacion = managedObject.value(forKey: "fechaCreacion") as? Date ?? Date()
        self.activo = managedObject.value(forKey: "activo") as? Bool ?? true
    }
    
    // Validar si el stock está bajo
    var tieneStockBajo: Bool {
        return stock <= stockMinimo
    }
    
    // Descripción del estado del producto
    var estadoStock: String {
        if tieneStockBajo {
            return "Stock Bajo"
        } else if stock > stockMinimo * 2 {
            return "Stock Alto"
        } else {
            return "Stock Normal"
        }
    }
}

// Extensión para categorías predefinidas
extension ProductoModel {
    static let categoriasPredefinidas = [
        "Medicamentos",
        "Equipos",
        "Insumos",
        "Dispositivos",
        "Consumibles"
    ]
}
