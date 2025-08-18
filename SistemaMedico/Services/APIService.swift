import Foundation

// MARK: - Modelos para API
struct ProductoAPI: Codable {
    let id: Int
    let nombre: String
    let categoria: String
    let precio: Double
    let descripcion: String?
}

struct ResponseAPI: Codable {
    let productos: [ProductoAPI]
    let total: Int
    let status: String
}

class APIService {
    static let shared = APIService()
    private let baseURL = "https://jsonplaceholder.typicode.com" // API de prueba
    
    private init() {}
    
    // MARK: - Obtener productos desde API
    func obtenerProductosDesdeAPI(completion: @escaping (Result<[ProductoAPI], Error>) -> Void) {
        // Simulamos productos médicos usando JSONPlaceholder
        guard let url = URL(string: "\(baseURL)/posts") else {
            completion(.failure(APIError.urlInvalida))
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(APIError.datosInvalidos))
                return
            }
            
            do {
                // Convertimos posts a productos médicos simulados
                let posts = try JSONDecoder().decode([Post].self, from: data)
                let productos = self.convertirPostsAProductos(posts: posts)
                completion(.success(productos))
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    // MARK: - Enviar pedido a servidor
    func enviarPedido(pedido: PedidoAPI, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/posts") else {
            completion(.failure(APIError.urlInvalida))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let jsonData = try JSONEncoder().encode(pedido)
            request.httpBody = jsonData
        } catch {
            completion(.failure(error))
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 201 {
                completion(.success("Pedido enviado exitosamente"))
            } else {
                completion(.failure(APIError.errorServidor))
            }
        }
        
        task.resume()
    }
    
    // MARK: - Métodos auxiliares
    private func convertirPostsAProductos(posts: [Post]) -> [ProductoAPI] {
        let categoriasMedicas = ["Medicamentos", "Equipos", "Insumos", "Dispositivos"]
        
        return posts.prefix(20).enumerated().map { index, post in
            ProductoAPI(
                id: post.id,
                nombre: "Producto Médico \(index + 1)",
                categoria: categoriasMedicas[index % categoriasMedicas.count],
                precio: Double.random(in: 10.0...500.0),
                descripcion: post.title
            )
        }
    }
}

// MARK: - Modelos auxiliares
struct Post: Codable {
    let id: Int
    let title: String
    let body: String
    let userId: Int
}

struct PedidoAPI: Codable {
    let cliente: String
    let destino: String
    let productos: [ProductoPedidoAPI]
    let total: Double
}

struct ProductoPedidoAPI: Codable {
    let id: Int
    let nombre: String
    let cantidad: Int
    let precio: Double
}

// MARK: - Errores personalizados
enum APIError: Error, LocalizedError {
    case urlInvalida
    case datosInvalidos
    case errorServidor
    
    var errorDescription: String? {
        switch self {
        case .urlInvalida:
            return "URL inválida"
        case .datosInvalidos:
            return "Datos inválidos recibidos"
        case .errorServidor:
            return "Error del servidor"
        }
    }
}
