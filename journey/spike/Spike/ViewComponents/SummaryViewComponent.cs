using Microsoft.AspNetCore.Mvc;

namespace Spike.ViewComponents;

public class SummaryModel
{
    public int Count { get; set; }
}

public class SummaryViewComponent : ViewComponent
{
    public IViewComponentResult Invoke(int count) => View(new SummaryModel { Count = 42 });
}
