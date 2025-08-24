import Foundation
import FirebaseFirestore
import CoreData

// MARK: - Modelos Firebase

struct ProductoFirebase: Codable {
    let nombre: String
    let categoria: String
    let precio: Double
    let descripcion: String
    let stock: Int
    let stockMinimo: Int
    let fechaCreacion: Date?
    let activo: Bool
    
    init(nombre: String, categoria: String, precio: Double, descripcion: String, stock: Int, stockMinimo: Int, fechaCreacion: Date? = Date(), activo: Bool = true) {
        self.nombre = nombre
        self.categoria = categoria
        self.precio = precio
        self.descripcion = descripcion
        self.stock = stock
        self.stockMinimo = stockMinimo
        self.fechaCreacion = fechaCreacion
        self.activo = activo
    }
    
    var dictionary: [String: Any] {
        return [
            "nombre": nombre,
            "categoria": categoria,
            "precio": precio,
            "descripcion": descripcion,
            "stock": stock,
            "stockMinimo": stockMinimo,
            "fechaCreacion": fechaCreacion != nil ? Timestamp(date: fechaCreacion!) : Timestamp(),
            "activo": activo
        ]
    }
}

struct PedidoFirebase: Codable {
    let id: String // ✅ NUEVO: ID único para evitar duplicados
    let cliente: String
    let destino: String
    let productos: [ProductoPedidoFirebase]
    let total: Double
    let estado: String
    let fechaCreacion: Date
    
    var dictionary: [String: Any] {
        return [
            "id": id,
            "cliente": cliente,
            "destino": destino,
            "productos": productos.map { $0.dictionary },
            "total": total,
            "estado": estado,
            "fechaCreacion": Timestamp(date: fechaCreacion)
        ]
    }
}

struct ProductoPedidoFirebase: Codable {
    let id: String
    let nombre: String
    let cantidad: Int
    let precio: Double
    
    var dictionary: [String: Any] {
        return [
            "id": id,
            "nombre": nombre,
            "cantidad": cantidad,
            "precio": precio
        ]
    }
}

enum FirebaseError: Error, LocalizedError {
    case documentoNoEncontrado
    case datosInvalidos
    case errorDeRed
    
    var errorDescription: String? {
        switch self {
        case .documentoNoEncontrado:
            return "Documento no encontrado en Firebase"
        case .datosInvalidos:
            return "Datos inválidos recibidos de Firebase"
        case .errorDeRed:
            return "Error de conexión con Firebase"
        }
    }
}

class FirebaseService {
    static let shared = FirebaseService()
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - Productos
    
    func obtenerProductosDesdeFirebase(completion: @escaping (Result<[ProductoAPI], Error>) -> Void) {
        db.collection("productos").whereField("activo", isEqualTo: true).getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let documents = snapshot?.documents else {
                completion(.success([]))
                return
            }
            
            let productos = documents.compactMap { doc -> ProductoAPI? in
                let data = doc.data()
                return ProductoAPI(
                    id: Int.random(in: 1...1000),
                    nombre: data["nombre"] as? String ?? "",
                    categoria: data["categoria"] as? String ?? "",
                    precio: data["precio"] as? Double ?? 0.0,
                    descripcion: data["descripcion"] as? String
                )
            }
            
            completion(.success(productos))
        }
    }
    
    func subirProducto(producto: ProductoFirebase, completion: @escaping (Result<String, Error>) -> Void) {
        let ref = db.collection("productos").addDocument(data: producto.dictionary) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success("Producto subido exitosamente"))
            }
        }
    }
    
    func actualizarProducto(nombre: String, nuevoStock: Int, completion: @escaping (Result<String, Error>) -> Void) {
        // Buscar producto por nombre
        db.collection("productos")
            .whereField("nombre", isEqualTo: nombre)
            .whereField("activo", isEqualTo: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    completion(.failure(FirebaseError.documentoNoEncontrado))
                    return
                }
                
                // Actualizar el primer documento encontrado
                let documentoRef = documents.first!.reference
                documentoRef.updateData(["stock": nuevoStock]) { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success("Stock actualizado en Firebase"))
                    }
                }
            }
    }
    
    func sincronizarTodosLosProductos(productos: [NSManagedObject], completion: @escaping (Result<String, Error>) -> Void) {
        let grupo = DispatchGroup()
        var errores: [Error] = []
        var actualizados = 0
        
        for producto in productos {
            let nombre = producto.value(forKey: "nombre") as? String ?? ""
            let categoria = producto.value(forKey: "categoria") as? String ?? ""
            let precio = producto.value(forKey: "precio") as? Double ?? 0.0
            let stock = producto.value(forKey: "stock") as? Int32 ?? 0
            let stockMinimo = producto.value(forKey: "stockMinimo") as? Int32 ?? 0
            
            grupo.enter()
            
            // Verificar si ya existe
            verificarOCrearProducto(nombre: nombre, categoria: categoria, precio: precio, stock: Int(stock), stockMinimo: Int(stockMinimo)) { result in
                switch result {
                case .success(_):
                    actualizados += 1
                case .failure(let error):
                    errores.append(error)
                }
                grupo.leave()
            }
        }
        
        grupo.notify(queue: .main) {
            if errores.isEmpty {
                completion(.success("✅ \(actualizados) productos sincronizados"))
            } else {
                completion(.failure(errores.first!))
            }
        }
    }
    
    private func verificarOCrearProducto(nombre: String, categoria: String, precio: Double, stock: Int, stockMinimo: Int, completion: @escaping (Result<String, Error>) -> Void) {
        db.collection("productos")
            .whereField("nombre", isEqualTo: nombre)
            .whereField("activo", isEqualTo: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                if let documents = snapshot?.documents, !documents.isEmpty {
                    // Producto existe, actualizar stock
                    let documentoRef = documents.first!.reference
                    documentoRef.updateData(["stock": stock]) { error in
                        if let error = error {
                            completion(.failure(error))
                        } else {
                            completion(.success("Producto actualizado"))
                        }
                    }
                } else {
                    // Crear nuevo
                    let nuevoProducto = ProductoFirebase(
                        nombre: nombre,
                        categoria: categoria,
                        precio: precio,
                        descripcion: "Producto médico",
                        stock: stock,
                        stockMinimo: stockMinimo
                    )
                    
                    self.subirProducto(producto: nuevoProducto, completion: completion)
                }
            }
    }
    
    // MARK: - ✅ MÉTODOS UNIVERSALES PARA PEDIDOS - SOLUCIONAN DUPLICADOS
    
    /// ✅ MÉTODO UNIVERSAL: Sincronizar pedido (crear o actualizar sin duplicados)
    func sincronizarPedidoUniversal(pedido: PedidoAPI, pedidoLocal: NSManagedObject, completion: @escaping (Result<String, Error>) -> Void) {
        // Generar ID único basado en cliente + fecha + total para identificar el pedido
        let cliente = pedidoLocal.value(forKey: "cliente") as? String ?? ""
        let fecha = pedidoLocal.value(forKey: "fechaCreacion") as? Date ?? Date()
        let total = pedidoLocal.value(forKey: "total") as? Double ?? 0.0
        
        let pedidoID = generarIDPedido(cliente: cliente, fecha: fecha, total: total)
        let estadoActual = pedidoLocal.value(forKey: "estado") as? String ?? "Pendiente"
        
        let pedidoFirebase = PedidoFirebase(
            id: pedidoID,
            cliente: pedido.cliente,
            destino: pedido.destino,
            productos: pedido.productos.map { ProductoPedidoFirebase(
                id: String($0.id),
                nombre: $0.nombre,
                cantidad: $0.cantidad,
                precio: $0.precio
            )},
            total: pedido.total,
            estado: estadoActual,
            fechaCreacion: fecha
        )
        
        // ✅ USAR setDocument CON ID ESPECÍFICO - EVITA DUPLICADOS
        db.collection("pedidos").document(pedidoID).setData(pedidoFirebase.dictionary, merge: true) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success("✅ Pedido sincronizado: \(estadoActual)"))
            }
        }
    }
    
    /// ✅ MÉTODO UNIVERSAL: Actualizar estado de pedido sin crear duplicados
    func actualizarEstadoPedido(pedidoLocal: NSManagedObject, nuevoEstado: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Generar mismo ID que se usó originalmente
        let cliente = pedidoLocal.value(forKey: "cliente") as? String ?? ""
        let fecha = pedidoLocal.value(forKey: "fechaCreacion") as? Date ?? Date()
        let total = pedidoLocal.value(forKey: "total") as? Double ?? 0.0
        
        let pedidoID = generarIDPedido(cliente: cliente, fecha: fecha, total: total)
        
        // ✅ ACTUALIZAR DOCUMENTO EXISTENTE
        db.collection("pedidos").document(pedidoID).updateData([
            "estado": nuevoEstado
        ]) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success("✅ Estado actualizado a: \(nuevoEstado)"))
            }
        }
    }
    
    /// ✅ MÉTODO UNIVERSAL: Generar ID único y consistente para pedidos
    private func generarIDPedido(cliente: String, fecha: Date, total: Double) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let fechaString = formatter.string(from: fecha)
        
        let clienteLimpio = cliente.replacingOccurrences(of: " ", with: "_")
                                  .replacingOccurrences(of: "[^A-Za-z0-9_]", with: "", options: .regularExpression)
        
        return "\(clienteLimpio)_\(fechaString)_\(Int(total * 100))"
    }
    
    // MARK: - ✅ MÉTODOS DE COMPATIBILIDAD (mantienen funcionalidad existente)
    
    func enviarPedido(pedido: PedidoAPI, completion: @escaping (Result<String, Error>) -> Void) {
        // ⚠️ MÉTODO LEGACY - usar sincronizarPedidoUniversal() en su lugar
        let pedidoFirebase = PedidoFirebase(
            id: "legacy_\(UUID().uuidString)",
            cliente: pedido.cliente,
            destino: pedido.destino,
            productos: pedido.productos.map { ProductoPedidoFirebase(
                id: String($0.id),
                nombre: $0.nombre,
                cantidad: $0.cantidad,
                precio: $0.precio
            )},
            total: pedido.total,
            estado: "Enviado",
            fechaCreacion: Date()
        )
        
        db.collection("pedidos").addDocument(data: pedidoFirebase.dictionary) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success("Pedido enviado exitosamente a Firebase"))
            }
        }
    }
    
    func enviarPedidoConEstado(pedido: PedidoAPI, estado: String = "Enviado", completion: @escaping (Result<String, Error>) -> Void) {
        // ⚠️ MÉTODO LEGACY - usar sincronizarPedidoUniversal() en su lugar
        let pedidoFirebase = PedidoFirebase(
            id: "legacy_\(UUID().uuidString)",
            cliente: pedido.cliente,
            destino: pedido.destino,
            productos: pedido.productos.map { ProductoPedidoFirebase(
                id: String($0.id),
                nombre: $0.nombre,
                cantidad: $0.cantidad,
                precio: $0.precio
            )},
            total: pedido.total,
            estado: estado,
            fechaCreacion: Date()
        )
        
        db.collection("pedidos").addDocument(data: pedidoFirebase.dictionary) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success("Pedido médico enviado exitosamente a Firebase con estado: \(estado)"))
            }
        }
    }
    
    func sincronizarPedidosEnviados(pedidosLocales: [NSManagedObject], completion: @escaping (Result<String, Error>) -> Void) {
        let pedidosEnviados = pedidosLocales.filter { pedido in
            let estado = pedido.value(forKey: "estado") as? String ?? ""
            return estado == "Enviado" || estado == "Entregado"
        }
        
        if pedidosEnviados.isEmpty {
            completion(.success("No hay pedidos enviados para sincronizar"))
            return
        }
        
        let grupo = DispatchGroup()
        var errores: [Error] = []
        var sincronizados = 0
        
        for pedido in pedidosEnviados {
            grupo.enter()
            
            // Convertir NSManagedObject a PedidoAPI
            let cliente = pedido.value(forKey: "cliente") as? String ?? ""
            let destino = pedido.value(forKey: "destino") as? String ?? ""
            let total = pedido.value(forKey: "total") as? Double ?? 0.0
            
            // Obtener productos del pedido
            let detalles = CoreDataManager.shared.obtenerDetallesPedido(pedido: pedido)
            var productos: [ProductoPedidoAPI] = []
            
            for detalle in detalles {
                if let productoEntity = detalle.value(forKey: "producto") as? NSManagedObject {
                    let nombre = productoEntity.value(forKey: "nombre") as? String ?? ""
                    let precio = productoEntity.value(forKey: "precio") as? Double ?? 0.0
                    let cantidad = detalle.value(forKey: "cantidad") as? Int32 ?? 0
                    
                    productos.append(ProductoPedidoAPI(
                        id: Int.random(in: 1...1000),
                        nombre: nombre,
                        cantidad: Int(cantidad),
                        precio: precio
                    ))
                }
            }
            
            let pedidoAPI = PedidoAPI(
                cliente: cliente,
                destino: destino,
                productos: productos,
                total: total
            )
            
            // ✅ USAR MÉTODO UNIVERSAL
            self.sincronizarPedidoUniversal(pedido: pedidoAPI, pedidoLocal: pedido) { resultado in
                switch resultado {
                case .success(_):
                    sincronizados += 1
                case .failure(let error):
                    errores.append(error)
                }
                grupo.leave()
            }
        }
        
        grupo.notify(queue: .main) {
            if errores.isEmpty {
                completion(.success("✅ \(sincronizados) pedidos sincronizados exitosamente"))
            } else {
                completion(.failure(errores.first!))
            }
        }
    }
}

extension FirebaseService {
    func sincronizarAutomaticamente() {
        obtenerProductosDesdeFirebase { result in
            switch result {
            case .success(let productos):
                self.actualizarCoreDataConProductos(productos)
            case .failure(let error):
                print("Error en sincronización automática: \(error)")
            }
        }
    }
    
    private func actualizarCoreDataConProductos(_ productos: [ProductoAPI]) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .productosActualizados, object: nil)
        }
    }
}
