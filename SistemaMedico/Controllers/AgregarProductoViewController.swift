import UIKit

class AgregarProductoViewController: UIViewController {
    
    // MARK: - Outlets
    @IBOutlet weak var txtNombre: UITextField!
    @IBOutlet weak var pickerCategoria: UIPickerView!
    @IBOutlet weak var txtPrecio: UITextField!
    @IBOutlet weak var txtStock: UITextField!
    @IBOutlet weak var txtStockMinimo: UITextField!
    @IBOutlet weak var btnGuardar: UIButton!
    
    // MARK: - Propiedades
    private let coreDataManager = CoreDataManager.shared
    private let categorias = ["Medicamentos", "Equipos", "Insumos", "Dispositivos", "Consumibles"]
    private var categoriaSeleccionada = "Medicamentos"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configurarUI()
        configurarPicker()
    }
    
    // MARK: - Configuración
    private func configurarUI() {
        title = "Nuevo Producto"
        
        // Botones de navegación
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelar)
        )
        
        // Configurar campos de texto
        txtNombre.placeholder = "Nombre del producto"
        txtPrecio.placeholder = "Precio (S/.)"
        txtStock.placeholder = "Stock inicial"
        txtStockMinimo.placeholder = "Stock mínimo"
        
        txtPrecio.keyboardType = .decimalPad
        txtStock.keyboardType = .numberPad
        txtStockMinimo.keyboardType = .numberPad
        
        // Configurar botón
        btnGuardar.backgroundColor = .systemBlue
        btnGuardar.setTitleColor(.white, for: .normal)
        btnGuardar.layer.cornerRadius = 10
        btnGuardar.setTitle("Guardar Producto", for: .normal)
        
        // Agregar toolbar para campos numéricos
        agregarToolbarATextFields()
    }
    
    private func configurarPicker() {
        pickerCategoria.delegate = self
        pickerCategoria.dataSource = self
    }
    
    private func agregarToolbarATextFields() {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        
        let botonListo = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(cerrarTeclado))
        let espacio = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        toolbar.setItems([espacio, botonListo], animated: false)
        
        txtPrecio.inputAccessoryView = toolbar
        txtStock.inputAccessoryView = toolbar
        txtStockMinimo.inputAccessoryView = toolbar
    }
    
    // MARK: - Acciones
    @objc private func cancelar() {
        dismiss(animated: true)
    }
    
    @objc private func cerrarTeclado() {
        view.endEditing(true)
    }
    
    // ACTUALIZADO: Guardar producto con NotificationCenter
    @IBAction func guardarProducto(_ sender: UIButton) {
        guard validarCampos() else { return }
        
        let nombre = txtNombre.text!.trimmingCharacters(in: .whitespacesAndNewlines)
        let precio = Double(txtPrecio.text!)!
        let stock = Int32(txtStock.text!)!
        let stockMinimo = Int32(txtStockMinimo.text!)!
        
        // Guardar en Core Data
        coreDataManager.crearProducto(
            nombre: nombre,
            categoria: categoriaSeleccionada,
            precio: precio,
            stock: stock,
            stockMinimo: stockMinimo
        )
        
        mostrarExito("✅ Producto guardado correctamente") {
            // NUEVO: Notificar actualización automática
            NotificationCenter.default.post(name: .productosActualizados, object: nil)
            
            self.dismiss(animated: true)
        }
    }
    
    // MARK: - Validación
    private func validarCampos() -> Bool {
        // Validar nombre
        guard let nombre = txtNombre.text, !nombre.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            mostrarError("Por favor ingrese el nombre del producto")
            return false
        }
        
        // Validar precio
        guard let precioTexto = txtPrecio.text, !precioTexto.isEmpty,
              let precio = Double(precioTexto), precio > 0 else {
            mostrarError("Por favor ingrese un precio válido")
            return false
        }
        
        // Validar stock
        guard let stockTexto = txtStock.text, !stockTexto.isEmpty,
              let stock = Int32(stockTexto), stock >= 0 else {
            mostrarError("Por favor ingrese un stock válido")
            return false
        }
        
        // Validar stock mínimo
        guard let stockMinimoTexto = txtStockMinimo.text, !stockMinimoTexto.isEmpty,
              let stockMinimo = Int32(stockMinimoTexto), stockMinimo >= 0 else {
            mostrarError("Por favor ingrese un stock mínimo válido")
            return false
        }
        
        return true
    }
    
    // MARK: - Métodos auxiliares
    private func mostrarError(_ mensaje: String) {
        let alert = UIAlertController(title: "Error", message: mensaje, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func mostrarExito(_ mensaje: String, completion: @escaping () -> Void) {
        let alert = UIAlertController(title: "Éxito", message: mensaje, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completion()
        })
        present(alert, animated: true)
    }
}

// MARK: - UIPickerViewDataSource
extension AgregarProductoViewController: UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return categorias.count
    }
}

// MARK: - UIPickerViewDelegate
extension AgregarProductoViewController: UIPickerViewDelegate {
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return categorias[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        categoriaSeleccionada = categorias[row]
    }
}
