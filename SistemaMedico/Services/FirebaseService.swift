import Foundation
import FirebaseFirestore
import Firebase
import CoreData

// MARK: - Modelos para Firebase
struct ProductoFirebase: Codable {
    var id: String?
    let nombre: String
    let categoria: String
    let precio: Double
    let descripcion: String
    let stock: Int
    let stockMinimo: Int
    let activo: Bool
    let fechaCreacion: Date
    
    // Inicializador desde ProductoAPI
    init(from producto: ProductoAPI) {
        self.id = nil
        self.nombre = producto.nombre
        self.categoria = producto.categoria
        self.precio = producto.precio
        self.descripcion = producto.descripcion ?? "Producto médico de alta calidad"
        self.stock = Int.random(in: 10...100)
        self.stockMinimo = Int.random(in: 5...20)
        self.activo = true
        self.fechaCreacion = Date()
    }
    
    // Inicializador personalizado con valores específicos de stock
    init(id: String? = nil,
         nombre: String,
         categoria: String,
         precio: Double,
         descripcion: String,
         stock: Int,
         stockMinimo: Int,
         activo: Bool = true,
         fechaCreacion: Date = Date()) {
        
        self.id = id
        self.nombre = nombre
        self.categoria = categoria
        self.precio = precio
        self.descripcion = descripcion
        self.stock = stock
        self.stockMinimo = stockMinimo
        self.activo = activo
        self.fechaCreacion = fechaCreacion
    }
    
    // Diccionario para Firestore
    var dictionary: [String: Any] {
        return [
            "nombre": nombre,
            "categoria": categoria,
            "precio": precio,
            "descripcion": descripcion,
            "stock": stock,
            "stockMinimo": stockMinimo,
            "activo": activo,
            "fechaCreacion": Timestamp(date: fechaCreacion)
        ]
    }
}

struct PedidoFirebase: Codable {
    var id: String?
    let cliente: String
    let destino: String
    let productos: [ProductoPedidoFirebase]
    let total: Double
    let estado: String
    let fechaCreacion: Date
    
    var dictionary: [String: Any] {
        return [
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
    
    // NUEVO: Método para actualizar producto existente en Firebase
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
    
    // NUEVO: Método para sincronizar TODOS los productos de CoreData a Firebase
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
            
            // Verificar si existe en Firebase
            verificarYActualizarProducto(
                nombre: nombre,
                categoria: categoria,
                precio: precio,
                stock: Int(stock),
                stockMinimo: Int(stockMinimo)
            ) { resultado in
                switch resultado {
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
                completion(.success("✅ \(actualizados) productos sincronizados correctamente"))
            } else {
                completion(.failure(errores.first!))
            }
        }
    }
    
    // NUEVO: Verificar si producto existe y actualizarlo o crearlo
    private func verificarYActualizarProducto(nombre: String, categoria: String, precio: Double, stock: Int, stockMinimo: Int, completion: @escaping (Result<String, Error>) -> Void) {
        
        db.collection("productos")
            .whereField("nombre", isEqualTo: nombre)
            .whereField("activo", isEqualTo: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                if let documents = snapshot?.documents, !documents.isEmpty {
                    // Producto existe, actualizar
                    let documentoRef = documents.first!.reference
                    documentoRef.updateData([
                        "stock": stock,
                        "stockMinimo": stockMinimo,
                        "precio": precio
                    ]) { error in
                        if let error = error {
                            completion(.failure(error))
                        } else {
                            completion(.success("Producto actualizado"))
                        }
                    }
                } else {
                    // Producto no existe, crear nuevo
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
    
    func enviarPedido(pedido: PedidoAPI, completion: @escaping (Result<String, Error>) -> Void) {
        let pedidoFirebase = PedidoFirebase(
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
    
    // MODIFICADO: Inicializar productos médicos con valores fijos específicos
    func inicializarProductosMedicos() {
        let productosMedicos = [
            ProductoFirebase(nombre: "Paracetamol 500mg", categoria: "Medicamentos", precio: 15.50, descripcion: "Analgésico y antipirético", stock: 100, stockMinimo: 20),
            ProductoFirebase(nombre: "Jeringas 5ml", categoria: "Insumos", precio: 2.30, descripcion: "Jeringas desechables estériles", stock: 500, stockMinimo: 100),
            ProductoFirebase(nombre: "Termómetro Digital", categoria: "Equipos", precio: 45.00, descripcion: "Termómetro digital infrarrojo", stock: 15, stockMinimo: 10),
            ProductoFirebase(nombre: "Mascarillas N95", categoria: "Insumos", precio: 8.75, descripcion: "Mascarillas de protección respiratoria", stock: 5, stockMinimo: 25),
            ProductoFirebase(nombre: "Oxímetro de Pulso", categoria: "Equipos", precio: 120.00, descripcion: "Medidor de saturación de oxígeno", stock: 8, stockMinimo: 5),
            ProductoFirebase(nombre: "Ibuprofeno 400mg", categoria: "Medicamentos", precio: 18.00, descripcion: "Antiinflamatorio no esteroideo", stock: 25, stockMinimo: 15),
            ProductoFirebase(nombre: "Alcohol en Gel", categoria: "Insumos", precio: 12.50, descripcion: "Alcohol en gel antibacterial", stock: 30, stockMinimo: 20),
            ProductoFirebase(nombre: "Tensiómetro Digital", categoria: "Equipos", precio: 85.00, descripcion: "Medidor de presión arterial", stock: 12, stockMinimo: 8)
        ]
        
        for producto in productosMedicos {
            verificarYActualizarProducto(
                nombre: producto.nombre,
                categoria: producto.categoria,
                precio: producto.precio,
                stock: producto.stock,
                stockMinimo: producto.stockMinimo
            ) { result in
                switch result {
                case .success(let mensaje):
                    print("✅ \(producto.nombre): \(mensaje)")
                case .failure(let error):
                    print("❌ Error con \(producto.nombre): \(error)")
                }
            }
        }
    }
}

// MARK: - Errores personalizados
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
