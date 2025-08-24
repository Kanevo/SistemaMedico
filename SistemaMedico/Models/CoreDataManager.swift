import Foundation
import CoreData

class CoreDataManager {
    static let shared = CoreDataManager()
    
    private init() {}
    
    // MARK: - Core Data Stack
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "SistemaMedico")
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Error al cargar Core Data: \(error), \(error.userInfo)")
            }
        }
        return container
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                fatalError("Error al guardar en Core Data: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    // MARK: - ✅ MÉTODOS PARA PRODUCTOS CORREGIDOS
    func crearProducto(nombre: String, categoria: String, precio: Double, stock: Int, stockMinimo: Int) {
        let producto = NSEntityDescription.entity(forEntityName: "Producto", in: context)!
        let nuevoProducto = NSManagedObject(entity: producto, insertInto: context)
        
        nuevoProducto.setValue(nombre, forKey: "nombre")
        nuevoProducto.setValue(categoria, forKey: "categoria")
        nuevoProducto.setValue(precio, forKey: "precio")
        nuevoProducto.setValue(Int32(stock), forKey: "stock") // ✅ Convertir Int a Int32 para Core Data
        nuevoProducto.setValue(Int32(stockMinimo), forKey: "stockMinimo") // ✅ Convertir Int a Int32 para Core Data
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
    
    // MARK: - ✅ MÉTODOS PARA DETALLE DE PEDIDO CON DESCUENTO AUTOMÁTICO
    
    /// ✅ CORREGIDO: Agregar detalle con descuento automático de stock
    func agregarDetallePedido(pedido: NSManagedObject, producto: NSManagedObject, cantidad: Int32) {
        let detalle = NSEntityDescription.entity(forEntityName: "DetallePedido", in: context)!
        let nuevoDetalle = NSManagedObject(entity: detalle, insertInto: context)
        
        nuevoDetalle.setValue(cantidad, forKey: "cantidad")
        nuevoDetalle.setValue(pedido, forKey: "pedido")
        nuevoDetalle.setValue(producto, forKey: "producto")
        
        // ✅ DESCUENTO AUTOMÁTICO DE STOCK
        let stockActual = producto.value(forKey: "stock") as! Int32
        let nuevoStock = stockActual - cantidad
        
        // Validación adicional para evitar stock negativo
        if nuevoStock < 0 {
            print("⚠️ Advertencia: El stock de \(producto.value(forKey: "nombre") ?? "producto") quedará negativo")
        }
        
        actualizarStockProducto(producto: producto, nuevoStock: nuevoStock)
        
        print("✅ Stock descontado automáticamente: \(producto.value(forKey: "nombre") ?? "producto") - \(cantidad) unidades. Stock nuevo: \(nuevoStock)")
        
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

// MARK: - ✅ EXTENSIONES PARA MANEJO AVANZADO

extension CoreDataManager {
    
    /// ✅ MEJORADO: Eliminar producto con verificación
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
    
    /// ✅ MEJORADO: Eliminar pedido con restauración automática de stock
    func eliminarPedido(_ pedido: NSManagedObject) {
        let detalles = obtenerDetallesPedido(pedido: pedido)
        
        // ✅ RESTAURAR STOCK AUTOMÁTICAMENTE
        for detalle in detalles {
            if let producto = detalle.value(forKey: "producto") as? NSManagedObject {
                let cantidad = detalle.value(forKey: "cantidad") as? Int32 ?? 0
                let stockActual = producto.value(forKey: "stock") as? Int32 ?? 0
                let nuevoStock = stockActual + cantidad
                
                producto.setValue(nuevoStock, forKey: "stock")
                
                print("✅ Stock restaurado automáticamente: \(producto.value(forKey: "nombre") ?? "producto") + \(cantidad) unidades. Stock nuevo: \(nuevoStock)")
            }
        }
        
        context.delete(pedido)
        saveContext()
    }
    
    /// ✅ NUEVO: Validar stock antes de crear pedido
    func validarStockParaPedido(productos: [(producto: NSManagedObject, cantidad: Int)]) -> (esValido: Bool, productosConError: [String]) {
        var productosConError: [String] = []
        
        for item in productos {
            if item.cantidad > 0 {
                let stockDisponible = item.producto.value(forKey: "stock") as? Int32 ?? 0
                let nombre = item.producto.value(forKey: "nombre") as? String ?? "Producto"
                
                if Int32(item.cantidad) > stockDisponible {
                    productosConError.append("\(nombre) (Disponible: \(stockDisponible), Solicitado: \(item.cantidad))")
                }
            }
        }
        
        return (productosConError.isEmpty, productosConError)
    }
    
    /// ✅ NUEVO: Obtener estadísticas del sistema
    func obtenerEstadisticas() -> (productos: Int, pedidos: Int, stockBajo: Int) {
        let productos = obtenerProductos().count
        let pedidos = obtenerPedidos().count
        let stockBajo = obtenerProductosStockBajo().count
        
        return (productos: productos, pedidos: pedidos, stockBajo: stockBajo)
    }
    
    /// ✅ NUEVO: Buscar productos por nombre
    func buscarProductos(porNombre nombre: String) -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Producto")
        request.predicate = NSPredicate(format: "nombre CONTAINS[c] %@ AND activo == %@", nombre, NSNumber(value: true))
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error al buscar productos: \(error)")
            return []
        }
    }
    
    /// ✅ NUEVO: Obtener productos por categoría
    func obtenerProductos(porCategoria categoria: String) -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Producto")
        request.predicate = NSPredicate(format: "categoria == %@ AND activo == %@", categoria, NSNumber(value: true))
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error al obtener productos por categoría: \(error)")
            return []
        }
    }
    
    /// ✅ NUEVO: Obtener pedidos por estado
    func obtenerPedidos(porEstado estado: String) -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Pedido")
        request.predicate = NSPredicate(format: "estado == %@", estado)
        let sortDescriptor = NSSortDescriptor(key: "fechaCreacion", ascending: false)
        request.sortDescriptors = [sortDescriptor]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error al obtener pedidos por estado: \(error)")
            return []
        }
    }
    }
