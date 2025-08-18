import Foundation
import CoreData

// Modelo para representar el detalle de un pedido
struct DetallePedidoModel {
    let cantidad: Int32
    let producto: ProductoModel?
    let subtotal: Double
    
    // Inicializador desde NSManagedObject
    init(from managedObject: NSManagedObject) {
        self.cantidad = managedObject.value(forKey: "cantidad") as? Int32 ?? 0
        
        // Obtener el producto relacionado
        if let productoManagedObject = managedObject.value(forKey: "producto") as? NSManagedObject {
            self.producto = ProductoModel(from: productoManagedObject)
            let precio = productoManagedObject.value(forKey: "precio") as? Double ?? 0.0
            self.subtotal = Double(cantidad) * precio
        } else {
            self.producto = nil
            self.subtotal = 0.0
        }
    }
    
    // Inicializador manual
    init(cantidad: Int32, producto: ProductoModel) {
        self.cantidad = cantidad
        self.producto = producto
        self.subtotal = Double(cantidad) * producto.precio
    }
    
    // Subtotal formateado como moneda
    var subtotalFormateado: String {
        return "S/. \(String(format: "%.2f", subtotal))"
    }
    
    // Descripción completa del detalle
    var descripcionCompleta: String {
        guard let producto = producto else {
            return "Producto no disponible"
        }
        
        return """
        \(producto.nombre)
        Cantidad: \(cantidad)
        Precio unitario: S/. \(String(format: "%.2f", producto.precio))
        Subtotal: \(subtotalFormateado)
        """
    }
    
    // Validar si la cantidad es válida
    var cantidadValida: Bool {
        return cantidad > 0
    }
}

// Extensión para operaciones con detalles de pedido
extension DetallePedidoModel {
    
    // Calcular total de una lista de detalles
    static func calcularTotal(detalles: [DetallePedidoModel]) -> Double {
        return detalles.reduce(0.0) { total, detalle in
            return total + detalle.subtotal
        }
    }
    
    // Obtener resumen de productos en el pedido
    static func obtenerResumen(detalles: [DetallePedidoModel]) -> String {
        let totalProductos = detalles.count
        let cantidadTotal = detalles.reduce(0) { total, detalle in
            return total + Int(detalle.cantidad)
        }
        let montoTotal = calcularTotal(detalles: detalles)
        
        return """
        Productos: \(totalProductos)
        Cantidad total: \(cantidadTotal) unidades
        Total: S/. \(String(format: "%.2f", montoTotal))
        """
    }
    
    // Validar stock disponible antes de crear el detalle
    static func validarStock(producto: ProductoModel, cantidadSolicitada: Int32) -> (esValido: Bool, mensaje: String) {
        if cantidadSolicitada <= 0 {
            return (false, "La cantidad debe ser mayor a 0")
        }
        
        if cantidadSolicitada > producto.stock {
            return (false, "Stock insuficiente. Disponible: \(producto.stock)")
        }
        
        return (true, "Stock disponible")
    }
}
