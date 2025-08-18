import UIKit
import CoreData
import Firebase
import FirebaseFirestore

class ReportesViewController: UIViewController {
    
    // MARK: - Propiedades
    private let coreDataManager = CoreDataManager.shared
    private var scrollView: UIScrollView!
    private var stackView: UIStackView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configurarUI()
        crearReportes()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        actualizarReportes()
    }
    
    // MARK: - Configuración
    private func configurarUI() {
        title = "Reportes"
        view.backgroundColor = .systemBackground
        
        // Crear scroll view
        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        // Crear stack view
        stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)
        
        // Configurar constraints
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])
    }
    
    private func crearReportes() {
        // Título principal
        let tituloLabel = crearLabel(texto: "📊 Dashboard de Reportes", fontSize: 24, weight: .bold)
        stackView.addArrangedSubview(tituloLabel)
        
        // Reporte de productos
        let reporteProductos = crearTarjetaReporte()
        stackView.addArrangedSubview(reporteProductos)
        
        // Reporte de pedidos
        let reportePedidos = crearTarjetaReporte()
        stackView.addArrangedSubview(reportePedidos)
        
        // Reporte de stock bajo
        let reporteStockBajo = crearTarjetaReporte()
        stackView.addArrangedSubview(reporteStockBajo)
        
        // Reporte de ventas por destino
        let reporteDestinos = crearTarjetaReporte()
        stackView.addArrangedSubview(reporteDestinos)
        
        // Botón de exportar
        let btnExportar = UIButton(type: .system)
        btnExportar.setTitle("📤 Exportar Reportes", for: .normal)
        btnExportar.backgroundColor = .systemBlue
        btnExportar.setTitleColor(.white, for: .normal)
        btnExportar.layer.cornerRadius = 10
        btnExportar.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        btnExportar.addTarget(self, action: #selector(exportarReportes), for: .touchUpInside)
        
        btnExportar.translatesAutoresizingMaskIntoConstraints = false
        btnExportar.heightAnchor.constraint(equalToConstant: 50).isActive = true
        
        stackView.addArrangedSubview(btnExportar)
    }
    
    private func crearTarjetaReporte() -> UIView {
        let contenedor = UIView()
        contenedor.backgroundColor = .systemBackground
        contenedor.layer.cornerRadius = 12
        contenedor.layer.shadowColor = UIColor.black.cgColor
        contenedor.layer.shadowOffset = CGSize(width: 0, height: 2)
        contenedor.layer.shadowRadius = 4
        contenedor.layer.shadowOpacity = 0.1
        contenedor.layer.borderWidth = 1
        contenedor.layer.borderColor = UIColor.systemGray5.cgColor
        
        return contenedor
    }
    
    private func crearLabel(texto: String, fontSize: CGFloat, weight: UIFont.Weight) -> UILabel {
        let label = UILabel()
        label.text = texto
        label.font = UIFont.systemFont(ofSize: fontSize, weight: weight)
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }
    
    private func actualizarReportes() {
        // Limpiar tarjetas anteriores
        for (index, vista) in stackView.arrangedSubviews.enumerated() {
            if index > 0 && index < stackView.arrangedSubviews.count - 1 {
                vista.subviews.forEach { $0.removeFromSuperview() }
            }
        }
        
        // Actualizar cada reporte
        actualizarReporteProductos()
        actualizarReportePedidos()
        actualizarReporteStockBajo()
        actualizarReporteDestinos()
    }
    
    private func actualizarReporteProductos() {
        guard stackView.arrangedSubviews.count > 1 else { return }
        let tarjeta = stackView.arrangedSubviews[1]
        
        let productos = coreDataManager.obtenerProductos()
        let totalProductos = productos.count
        let categorias = Set(productos.compactMap { $0.value(forKey: "categoria") as? String })
        let valorTotal = productos.reduce(0.0) { total, producto in
            let precio = producto.value(forKey: "precio") as? Double ?? 0.0
            let stock = producto.value(forKey: "stock") as? Int32 ?? 0
            return total + (precio * Double(stock))
        }
        
        let stackTarjeta = UIStackView()
        stackTarjeta.axis = .vertical
        stackTarjeta.spacing = 8
        stackTarjeta.translatesAutoresizingMaskIntoConstraints = false
        
        stackTarjeta.addArrangedSubview(crearLabel(texto: "📦 Inventario de Productos", fontSize: 18, weight: .semibold))
        stackTarjeta.addArrangedSubview(crearLabel(texto: "Total de productos: \(totalProductos)", fontSize: 16, weight: .regular))
        stackTarjeta.addArrangedSubview(crearLabel(texto: "Categorías: \(categorias.count)", fontSize: 16, weight: .regular))
        stackTarjeta.addArrangedSubview(crearLabel(texto: "Valor total: S/. \(String(format: "%.2f", valorTotal))", fontSize: 16, weight: .medium))
        
        tarjeta.addSubview(stackTarjeta)
        
        NSLayoutConstraint.activate([
            stackTarjeta.topAnchor.constraint(equalTo: tarjeta.topAnchor, constant: 16),
            stackTarjeta.leadingAnchor.constraint(equalTo: tarjeta.leadingAnchor, constant: 16),
            stackTarjeta.trailingAnchor.constraint(equalTo: tarjeta.trailingAnchor, constant: -16),
            stackTarjeta.bottomAnchor.constraint(equalTo: tarjeta.bottomAnchor, constant: -16)
        ])
    }
    
    private func actualizarReportePedidos() {
        guard stackView.arrangedSubviews.count > 2 else { return }
        let tarjeta = stackView.arrangedSubviews[2]
        
        let pedidos = coreDataManager.obtenerPedidos()
        let totalPedidos = pedidos.count
        let pedidosPendientes = pedidos.filter { ($0.value(forKey: "estado") as? String) == "Pendiente" }.count
        let pedidosEntregados = pedidos.filter { ($0.value(forKey: "estado") as? String) == "Entregado" }.count
        let ventasTotal = pedidos.reduce(0.0) { total, pedido in
            return total + (pedido.value(forKey: "total") as? Double ?? 0.0)
        }
        
        let stackTarjeta = UIStackView()
        stackTarjeta.axis = .vertical
        stackTarjeta.spacing = 8
        stackTarjeta.translatesAutoresizingMaskIntoConstraints = false
        
        stackTarjeta.addArrangedSubview(crearLabel(texto: "📋 Estado de Pedidos", fontSize: 18, weight: .semibold))
        stackTarjeta.addArrangedSubview(crearLabel(texto: "Total de pedidos: \(totalPedidos)", fontSize: 16, weight: .regular))
        stackTarjeta.addArrangedSubview(crearLabel(texto: "Pendientes: \(pedidosPendientes)", fontSize: 16, weight: .regular))
        stackTarjeta.addArrangedSubview(crearLabel(texto: "Entregados: \(pedidosEntregados)", fontSize: 16, weight: .regular))
        stackTarjeta.addArrangedSubview(crearLabel(texto: "Ventas totales: S/. \(String(format: "%.2f", ventasTotal))", fontSize: 16, weight: .medium))
        
        tarjeta.addSubview(stackTarjeta)
        
        NSLayoutConstraint.activate([
            stackTarjeta.topAnchor.constraint(equalTo: tarjeta.topAnchor, constant: 16),
            stackTarjeta.leadingAnchor.constraint(equalTo: tarjeta.leadingAnchor, constant: 16),
            stackTarjeta.trailingAnchor.constraint(equalTo: tarjeta.trailingAnchor, constant: -16),
            stackTarjeta.bottomAnchor.constraint(equalTo: tarjeta.bottomAnchor, constant: -16)
        ])
    }
    
    private func actualizarReporteStockBajo() {
        guard stackView.arrangedSubviews.count > 3 else { return }
        let tarjeta = stackView.arrangedSubviews[3]
        
        let productosStockBajo = coreDataManager.obtenerProductosStockBajo()
        
        let stackTarjeta = UIStackView()
        stackTarjeta.axis = .vertical
        stackTarjeta.spacing = 8
        stackTarjeta.translatesAutoresizingMaskIntoConstraints = false
        
        stackTarjeta.addArrangedSubview(crearLabel(texto: "⚠️ Alertas de Stock", fontSize: 18, weight: .semibold))
        stackTarjeta.addArrangedSubview(crearLabel(texto: "Productos con stock bajo: \(productosStockBajo.count)", fontSize: 16, weight: .regular))
        
        if productosStockBajo.count > 0 {
            let labelAlerta = crearLabel(texto: "¡Requiere atención inmediata!", fontSize: 14, weight: .medium)
            labelAlerta.textColor = .systemRed
            stackTarjeta.addArrangedSubview(labelAlerta)
            
            for (index, producto) in productosStockBajo.prefix(3).enumerated() {
                let nombre = producto.value(forKey: "nombre") as? String ?? ""
                let stock = producto.value(forKey: "stock") as? Int32 ?? 0
                let labelProducto = crearLabel(texto: "• \(nombre): \(stock) unidades", fontSize: 14, weight: .regular)
                labelProducto.textColor = .systemRed
                labelProducto.textAlignment = .left
                stackTarjeta.addArrangedSubview(labelProducto)
            }
        } else {
            let labelOk = crearLabel(texto: "✅ Todos los productos tienen stock adecuado", fontSize: 14, weight: .regular)
            labelOk.textColor = .systemGreen
            stackTarjeta.addArrangedSubview(labelOk)
        }
        
        tarjeta.addSubview(stackTarjeta)
        
        NSLayoutConstraint.activate([
            stackTarjeta.topAnchor.constraint(equalTo: tarjeta.topAnchor, constant: 16),
            stackTarjeta.leadingAnchor.constraint(equalTo: tarjeta.leadingAnchor, constant: 16),
            stackTarjeta.trailingAnchor.constraint(equalTo: tarjeta.trailingAnchor, constant: -16),
            stackTarjeta.bottomAnchor.constraint(equalTo: tarjeta.bottomAnchor, constant: -16)
        ])
    }
    
    private func actualizarReporteDestinos() {
        guard stackView.arrangedSubviews.count > 4 else { return }
        let tarjeta = stackView.arrangedSubviews[4]
        
        let pedidos = coreDataManager.obtenerPedidos()
        var ventasPorDestino: [String: Double] = [:]
        
        for pedido in pedidos {
            let destino = pedido.value(forKey: "destino") as? String ?? ""
            let total = pedido.value(forKey: "total") as? Double ?? 0.0
            ventasPorDestino[destino] = (ventasPorDestino[destino] ?? 0.0) + total
        }
        
        let stackTarjeta = UIStackView()
        stackTarjeta.axis = .vertical
        stackTarjeta.spacing = 8
        stackTarjeta.translatesAutoresizingMaskIntoConstraints = false
        
        stackTarjeta.addArrangedSubview(crearLabel(texto: "🗺️ Ventas por Destino", fontSize: 18, weight: .semibold))
        
        let destinosOrdenados = ventasPorDestino.sorted { $0.value > $1.value }
        
        if destinosOrdenados.isEmpty {
            stackTarjeta.addArrangedSubview(crearLabel(texto: "No hay ventas registradas", fontSize: 14, weight: .regular))
        } else {
            for (destino, total) in destinosOrdenados.prefix(5) {
                let labelDestino = crearLabel(texto: "• \(destino): S/. \(String(format: "%.2f", total))", fontSize: 14, weight: .regular)
                labelDestino.textAlignment = .left
                stackTarjeta.addArrangedSubview(labelDestino)
            }
        }
        
        tarjeta.addSubview(stackTarjeta)
        
        NSLayoutConstraint.activate([
            stackTarjeta.topAnchor.constraint(equalTo: tarjeta.topAnchor, constant: 16),
            stackTarjeta.leadingAnchor.constraint(equalTo: tarjeta.leadingAnchor, constant: 16),
            stackTarjeta.trailingAnchor.constraint(equalTo: tarjeta.trailingAnchor, constant: -16),
            stackTarjeta.bottomAnchor.constraint(equalTo: tarjeta.bottomAnchor, constant: -16)
        ])
    }
    
    @objc private func exportarReportes() {
        let alert = UIAlertController(title: "Funcionalidad Futura", message: "La exportación de reportes será implementada en una próxima versión.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
