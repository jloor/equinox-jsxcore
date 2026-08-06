using Microsoft.AspNetCore.Mvc;

namespace Spike.Controllers;

public class CustomerViewModel
{
    public string Name { get; set; } = "";
    public string Email { get; set; } = "";
}

public class CustomerController : Controller
{
    private static readonly List<CustomerViewModel> Store = [];

    [HttpGet]
    public IActionResult Create() => View(new CustomerViewModel());

    [HttpGet]
    public IActionResult Summary() => ViewComponent("Summary", new { count = Store.Count });

    [HttpPost]
    [ValidateAntiForgeryToken]
    public IActionResult Create(CustomerViewModel model)
    {
        Store.Add(model);
        return Content($"CREATED name={model.Name} email={model.Email} total={Store.Count}");
    }
}
