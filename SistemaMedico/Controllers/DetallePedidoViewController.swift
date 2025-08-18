import UIKit
import CoreData

class DetallePedidoViewController: UIViewController {
    
    // MARK: - Outlets
    @IBOutlet weak var lblCliente: UILabel!
    @IBOutlet weak var lblDestino: UILabel!
    @IBOutlet weak var lblFecha: UILabel!
    @IBOutlet weak var lblEstado: UILabel!
    @IBOutlet weak var lblTotal: UILabel!
    @IBOutlet weak var tableViewDetalles: UITableView!
    @IBOutlet weak var btnCambiarEstado: UIButton!
    
    // MARK: - Propiedades
    var pedido: NSManagedObject!
    private let coreDataManager = CoreDataManager.shared
    private var detallesPedido: [NSManagedObject] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configurarUI()
        configurarTableView()
        cargarDatos()
    }
    
    // MARK: - Configuración
    private func configurarUI() {
        title = "Detalle del Pedido"
        
        btnCambiarEstado.backgroundColor = .systemBlue
        btnCambiarEstado.setTitleColor(.white, for: .normal)
        btnCambiarEstado.layer.cornerRadius = 10
        btnCambiarEstado.setTitle("Cambiar Estado", for: .normal)
    }
    
    private func configurarTableView() {
        tableViewDetalles.delegate = self
        tableViewDetalles.dataSource = self
        tableViewDetalles.register(UITableViewCell.self, forCellReuseIdentifier: "CeldaDetalle")
    }
    
    // MARK: - Acciones
    @IBAction func cambiarEstado(_ sender: UIButton) {
        let estadoActual = pedido.value(forKey: "estado") as? String ?? "Pendiente"
        
        let alert = UIAlertController(title: "Cambiar Estado", message: "Estado actual: \(estadoActual)", preferredStyle: .actionSheet)
        
        let estados = ["Pendiente", "Preparando", "Enviado", "Entregado", "Cancelado"]
        
        for estado in estados {
            if estado != estadoActual {
                alert.addAction(UIAlertAction(title: estado, style: .default) { _ in
                    self.coreDataManager.actualizarEstadoPedido(pedido: self.pedido, estado: estado)
                    self.cargarDatos()
                })
            }
        }
        
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        
        // Para iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = sender
            popover.sourceRect = sender.bounds
        }
        
        present(alert, animated: true)
    }
    
    // MARK: - Métodos
    private func cargarDatos() {
        guard pedido != nil else { return }
        
        // Cargar información del pedido
        let cliente = pedido.value(forKey: "cliente") as? String ?? ""
        let destino = pedido.value(forKey: "destino") as? String ?? ""
        let estado = pedido.value(forKey: "estado") as? String ?? ""
        let total = pedido.value(forKey: "total") as? Double ?? 0.0
        
        lblCliente.text = "Cliente: \(cliente)"
        lblDestino.text = "Destino: \(destino)"
        lblEstado.text = "Estado: \(estado)"
        lblTotal.text = "Total: S/. \(String(format: "%.2f", total))"
        
        // Configurar color del estado
        switch estado {
        case "Pendiente":
            lblEstado.textColor = .systemOrange
        case "Preparando":
            lblEstado.textColor = .systemBlue
        case "Enviado":
            lblEstado.textColor = .systemPurple
        case "Entregado":
            lblEstado.textColor = .systemGreen
        case "Cancelado":
            lblEstado.textColor = .systemRed
        default:
            lblEstado.textColor = .label
        }
        
        if let fecha = pedido.value(forKey: "fechaCreacion") as? Date {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            lblFecha.text = "Fecha: \(formatter.string(from: fecha))"
        }
        
        // Cargar detalles del pedido
        detallesPedido = coreDataManager.obtenerDetallesPedido(pedido: pedido)
        tableViewDetalles.reloadData()
    }
}

// MARK: - UITableViewDataSource
extension DetallePedidoViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return detallesPedido.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CeldaDetalle", for: indexPath)
        
        let detalle = detallesPedido[indexPath.row]
        let cantidad = detalle.value(forKey: "cantidad") as? Int32 ?? 0
        
        if let producto = detalle.value(forKey: "producto") as? NSManagedObject {
            let nombre = producto.value(forKey: "nombre") as? String ?? ""
            let precio = producto.value(forKey: "precio") as? Double ?? 0.0
            let subtotal = Double(cantidad) * precio
            
            cell.textLabel?.text = nombre
            cell.detailTextLabel?.text = "Cantidad: \(cantidad) • Precio: S/. \(String(format: "%.2f", precio)) • Subtotal: S/. \(String(format: "%.2f", subtotal))"
        }
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension DetallePedidoViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Productos del Pedido"
    }
}
