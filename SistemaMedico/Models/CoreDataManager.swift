import Foundation
import CoreData
import UIKit

class CoreDataManager {
    static let shared = CoreDataManager()
    
    private init() {}
    
    // MARK: - Core Data Stack
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "SistemaMedico")
        container.loadPersistentStores(completionHandler: { _, error in
            if let error = error as NSError? {
                fatalError("Error al cargar Core Data: \(error), \(error.userInfo)")
            }
        })
        return container
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // MARK: - Core Data Saving
    func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                fatalError("Error al guardar: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    // MARK: - Métodos para Productos
    func crearProducto(nombre: String, categoria: String, precio: Double, stock: Int32, stockMinimo: Int32) {
        let producto = NSEntityDescription.entity(forEntityName: "Producto", in: context)!
        let nuevoProducto = NSManagedObject(entity: producto, insertInto: context)
        
        nuevoProducto.setValue(nombre, forKey: "nombre")
        nuevoProducto.setValue(categoria, forKey: "categoria")
        nuevoProducto.setValue(precio, forKey: "precio")
        nuevoProducto.setValue(stock, forKey: "stock")
        nuevoProducto.setValue(stockMinimo, forKey: "stockMinimo")
        nuevoProducto.setValue(Date(), forKey: "fechaCreacion")
        nuevoProducto.setValue(true, forKey: "activo")
        
        saveContext()
    }
    
    func obtenerProductos() -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Producto")
        request.predicate = NSPredicate(format: "activo == %@", NSNumber(value: true))
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error al obtener productos: \(error)")
            return []
        }
    }
    
    func obtenerProductosStockBajo() -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Producto")
        request.predicate = NSPredicate(format: "stock <= stockMinimo AND activo == %@", NSNumber(value: true))
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error al obtener productos con stock bajo: \(error)")
            return []
        }
    }
    
    func actualizarStockProducto(producto: NSManagedObject, nuevoStock: Int32) {
        producto.setValue(nuevoStock, forKey: "stock")
        saveContext()
    }
    
    // MARK: - Métodos para Pedidos
    func crearPedido(cliente: String, destino: String, total: Double) -> NSManagedObject {
        let pedido = NSEntityDescription.entity(forEntityName: "Pedido", in: context)!
        let nuevoPedido = NSManagedObject(entity: pedido, insertInto: context)
        
        nuevoPedido.setValue(cliente, forKey: "cliente")
        nuevoPedido.setValue(destino, forKey: "destino")
        nuevoPedido.setValue(total, forKey: "total")
        nuevoPedido.setValue(Date(), forKey: "fechaCreacion")
        nuevoPedido.setValue("Pendiente", forKey: "estado")
        
        saveContext()
        return nuevoPedido
    }
    
    func obtenerPedidos() -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Pedido")
        let sortDescriptor = NSSortDescriptor(key: "fechaCreacion", ascending: false)
        request.sortDescriptors = [sortDescriptor]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error al obtener pedidos: \(error)")
            return []
        }
    }
    
    func actualizarEstadoPedido(pedido: NSManagedObject, estado: String) {
        pedido.setValue(estado, forKey: "estado")
        saveContext()
    }
    
    // MARK: - Métodos para Detalle de Pedido
    func agregarDetallePedido(pedido: NSManagedObject, producto: NSManagedObject, cantidad: Int32) {
        let detalle = NSEntityDescription.entity(forEntityName: "DetallePedido", in: context)!
        let nuevoDetalle = NSManagedObject(entity: detalle, insertInto: context)
        
        nuevoDetalle.setValue(cantidad, forKey: "cantidad")
        nuevoDetalle.setValue(pedido, forKey: "pedido")
        nuevoDetalle.setValue(producto, forKey: "producto")
        
        // Actualizar stock del producto
        let stockActual = producto.value(forKey: "stock") as! Int32
        let nuevoStock = stockActual - cantidad
        actualizarStockProducto(producto: producto, nuevoStock: nuevoStock)
        
        saveContext()
    }
    
    func obtenerDetallesPedido(pedido: NSManagedObject) -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "DetallePedido")
        request.predicate = NSPredicate(format: "pedido == %@", pedido)
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error al obtener detalles del pedido: \(error)")
            return []
        }
    }
}

extension CoreDataManager {
    func eliminarProducto(_ producto: NSManagedObject) -> Bool {
        if productoTienePedidosAsociados(producto) {
            return false
        }
        producto.setValue(false, forKey: "activo")
        saveContext()
        return true
    }
    
    private func productoTienePedidosAsociados(_ producto: NSManagedObject) -> Bool {
        let request = NSFetchRequest<NSManagedObject>(entityName: "DetallePedido")
        request.predicate = NSPredicate(format: "producto == %@", producto)
        
        do {
            let detalles = try context.fetch(request)
            return !detalles.isEmpty
        } catch {
            return true
        }
    }
    
    func eliminarPedido(_ pedido: NSManagedObject) {
        let detalles = obtenerDetallesPedido(pedido: pedido)
        
        for detalle in detalles {
            if let producto = detalle.value(forKey: "producto") as? NSManagedObject {
                let cantidad = detalle.value(forKey: "cantidad") as? Int32 ?? 0
                let stockActual = producto.value(forKey: "stock") as? Int32 ?? 0
                producto.setValue(stockActual + cantidad, forKey: "stock")
            }
        }
        
        context.delete(pedido)
        saveContext()
    }
}
