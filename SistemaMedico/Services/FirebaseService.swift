import Foundation
import FirebaseFirestore
import Firebase

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
    
    // Método para inicializar productos médicos de ejemplo
    func inicializarProductosMedicos() {
        let productosMedicos = [
            ProductoFirebase(from: ProductoAPI(id: 1, nombre: "Paracetamol 500mg", categoria: "Medicamentos", precio: 15.50, descripcion: "Analgésico y antipirético")),
            ProductoFirebase(from: ProductoAPI(id: 2, nombre: "Jeringas 5ml", categoria: "Insumos", precio: 2.30, descripcion: "Jeringas desechables estériles")),
            ProductoFirebase(from: ProductoAPI(id: 3, nombre: "Termómetro Digital", categoria: "Equipos", precio: 45.00, descripcion: "Termómetro digital infrarrojo")),
            ProductoFirebase(from: ProductoAPI(id: 4, nombre: "Mascarillas N95", categoria: "Insumos", precio: 8.75, descripcion: "Mascarillas de protección respiratoria")),
            ProductoFirebase(from: ProductoAPI(id: 5, nombre: "Oxímetro de Pulso", categoria: "Equipos", precio: 120.00, descripcion: "Medidor de saturación de oxígeno")),
            ProductoFirebase(from: ProductoAPI(id: 6, nombre: "Ibuprofeno 400mg", categoria: "Medicamentos", precio: 18.00, descripcion: "Antiinflamatorio no esteroideo")),
            ProductoFirebase(from: ProductoAPI(id: 7, nombre: "Alcohol en Gel", categoria: "Insumos", precio: 12.50, descripcion: "Alcohol en gel antibacterial")),
            ProductoFirebase(from: ProductoAPI(id: 8, nombre: "Tensiómetro Digital", categoria: "Equipos", precio: 85.00, descripcion: "Medidor de presión arterial"))
        ]
        
        for producto in productosMedicos {
            subirProducto(producto: producto) { result in
                switch result {
                case .success(let mensaje):
                    print("✅ \(producto.nombre): \(mensaje)")
                case .failure(let error):
                    print("❌ Error subiendo \(producto.nombre): \(error)")
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
